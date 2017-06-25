module WebkitRemote

class Client

# API for the Runtime domain.
module Runtime
  # Evals a JavaScript expression.
  #
  # @param [String] expression the JavaScript expression to be evaluated
  # @param [Hash] opts tweaks
  # @option opts [String, Symbol] group the name of an object group (think
  #     memory pools); the objects in a group can be released together by one
  #     call to WebkitRemote::Client::JsObjectGroup#release
  # @return [WebkitRemote::Client::JsObject, Boolean, Number, String] the
  #     result of evaluating the expression
  def remote_eval(expression, opts = {})
    group_name = opts[:group] || object_group_auto_name
    # NOTE: returnByValue is always set to false to avoid some extra complexity
    result = @rpc.call 'Runtime.evaluate', expression: expression,
                       objectGroup: group_name
    object = WebkitRemote::Client::JsObject.for result['result'], self,
                                                    group_name
    if result['wasThrown']
      # TODO(pwnall): some wrapper for exceptions?
      object
    else
      object
    end
  end

  # Retrieves a group of remote objects by its name.
  #
  # @param [String, Symbol] group_name name given to remote_eval when the
  #     object was created; nil obtains the anonymous group containing the
  #     un-grouped objects created by Console#MessageReceived
  # @param [Boolean] create if true, fetching a group that does not exist will
  #     create the group; this parameter should only be used internally
  # @return [WebkitRemote::Client::JsObject, Boolean, Number, String, nil]
  #     a Ruby wrapper for the evaluation result; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by JsObject
  #     instances
  def object_group(group_name, create = false)
    group_name = group_name.nil? ? nil : group_name.to_s
    group = @runtime_groups[group_name]
    return group if group
    if create
      @runtime_groups[group_name] =
          WebkitRemote::Client::JsObjectGroup.new(group_name, self)
    else
      nil
    end
  end

  # Generates a temporary group name for JavaScript objects.
  #
  # This is useful when the API user does not
  #
  # @return [String] an automatically-generated JS object name
  def object_group_auto_name
    '_'
  end

  # Removes a group from the list of tracked groups.
  #
  # @private Use WebkitRemote::Client::JsObjectGroup#release instead of
  #     calling this directly.
  # @return [WebkitRemote::Client] self
  def object_group_remove(group)
    @runtime_groups.delete group.name
    self
  end

  # @private Called by the WebkitRemote::Client constructor.
  def initialize_runtime()
    @runtime_groups = {}
  end

  # Releases all the objects allocated to this runtime.
  #
  # @return [WebkitRemote::Client] self
  def clear_runtime
    @runtime_groups.each do |name, group|
      group.release_all
    end
    self
  end
end  # module WebkitRemote::Client::Runtime

initializer :initialize_runtime
clearer :clear_runtime
include WebkitRemote::Client::Runtime

# The class of the JavaScript undefined object.
class UndefinedClass
  def js_undefined?
    true
  end

  def empty?
    true
  end

  def blank?
    true
  end

  def to_a
    []
  end

  def to_s
    ''
  end

  def to_i
    0
  end

  def to_f
    0.0
  end

  def inspect
    'JavaScript undefined'
  end

  def release
    self
  end

  def released?
    true
  end
end  # class WebkitRemote::Client::UndefinedClass

Undefined = UndefinedClass.new

# Mirrors a JsObject, defined in the Runtime domain.
class JsObject
  # @return [String] the class name computed by WebKit for this object
  attr_reader :js_class_name

  # @return [String] the return value of the JavaScript typeof operator
  attr_reader :js_type

  # @return [Symbol] an additional type hint for this object; documented values
  #     are :array, :date, :node, :null, :regexp
  attr_reader :js_subtype

  # @return [String] string that would be displayed in the Webkit console to
  #     represent this object
  attr_reader :description

  # @return [Object] primitive value for this object, if available
  attr_reader :value

  # @return [Hash<String, Object>] the raw info provided by the remote debugger
  #     RPC call; might be useful for accessing extended metadata that is not
  #     (yet) recognized by WebkitRemote
  attr_reader :raw_data

  # @return [Boolean] true if the objects in this group were already released
  attr_reader :released
  alias_method :released?, :released

  # @return [WebkitRemote::Client] remote debugging client for the browser tab
  #     that owns the objects in this group
  attr_reader :client

  # @return [WebkitRemote::Client::JsObjectGroup] the group that contains
  #     this object; the object can be released by calling release_all on the
  #     group
  attr_reader :group

  # @return [String] identifies this object in the remote debugger
  # @private Use the JsObject methods instead of calling this directly.
  attr_reader :remote_id

  # Releases this remote object on the browser side.
  #
  # @return [Webkit::Client::JsObject] self
  def release
    return if @released
    @client.rpc.call 'Runtime.releaseObject', objectId: @remote_id
    @group.remove self
    released!
  end

  # This object's properties.
  #
  # If the object's properties have not been retrieved, this method retrieves
  # them via a RPC call.
  #
  # @return [Hash<String, Webkit::Client::JsProperty>] frozen Hash containg
  #     the object's properties
  def properties
    @properties || properties!
  end

  # This object's properties, guaranteed to be fresh.
  #
  # This method always reloads the object's properties via a RPC call.
  #
  # @return [Hash<Symbol, Webkit::Client::JsProperty>] frozen Hash containg
  #     the object's properties
  def properties!
    result = @client.rpc.call 'Runtime.getProperties', objectId: @remote_id
    @properties = Hash[
      result['result'].map do |raw_property|
        property = WebkitRemote::Client::JsProperty.new raw_property, self
        [property.name, property]
      end
    ].freeze
  end

  # Calls a function with "this" bound to this object.
  #
  # @param [String] function_expression a JavaScript expression that should
  #     evaluate to a function
  # @param [Array<WebkitRemote::Client::Object, String, Number, Boolean, nil>]
  #     args the arguments passed to the function
  # @return [WebkitRemote::Client::JsObject, Boolean, Number, String, nil]
  #     a Ruby wrapper for the given raw object; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by JsObject
  #     instances
  def bound_call(function_expression, *args)
    call_args = args.map do |arg|
      if arg.kind_of? WebkitRemote::Client::JsObject
        { objectId: arg.remote_id }
      else
        { value: arg }
      end
    end
    result = @client.rpc.call 'Runtime.callFunctionOn', objectId: @remote_id,
        functionDeclaration: function_expression, arguments: call_args,
        returnByValue: false
    object = WebkitRemote::Client::JsObject.for result['result'], @client,
                                                    @group.name
    if result['wasThrown']
      # TODO(pwnall): some wrapper for exceptions?
      object
    else
      object
    end
  end

  # Wraps a raw object returned by the Webkit remote debugger RPC protocol.
  #
  # @private Use WebkitRemote::Client::Runtime#remote_eval instead of calling
  #     this directly.
  #
  # @param [Hash<String, Object>] raw_object a JsObject instance, according
  #     to the Webkit remote debugging protocol; this is the return value of a
  #     'Runtime.evaluate' RPC call
  # @param [WebkitRemote::Client::Runtime] client remote debugging client for
  #     the browser tab that owns this object
  # @param [String] group_name name of the object group that will hold this
  #     object; object groups work like memory pools
  # @return [WebkitRemote::Client::JsObject, Boolean, Number, String] a
  #     Ruby wrapper for the given raw object; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by JsObject
  #     instances
  def self.for(raw_object, client, group_name)
    if remote_id = raw_object['objectId']
      group = client.object_group group_name, true
      return group.get(remote_id) ||
             WebkitRemote::Client::JsObject.new(raw_object, group)
    else
      # primitive types
      case raw_object['type'] ? raw_object['type'].to_sym : nil
      when :boolean, :number, :string
        return raw_object['value']
      when :undefined
        return WebkitRemote::Client::Undefined
      when :object
        case raw_object['subtype'] ? raw_object['subtype'].to_sym : nil
        when :null
          return nil
        end
        # TODO(pwnall): Any other exceptions?
      end
    end
    raise RuntimeError, "Unable to parse #{raw_object.inspect}"
  end

  # Wraps a remote JavaScript object
  #
  # @private JsObject#for should be used instead of this, as it handles
  #     some edge cases
  def initialize(raw_object, group)
    @group = group
    @client = group.client
    @released = false

    @raw_data = raw_object
    @remote_id = raw_object['objectId']
    @js_class_name = raw_object['className']
    @description = raw_object['description']
    @js_type = raw_object['type'].to_sym
    if raw_object['subtype']
      @js_subtype = raw_object['subtype'].to_sym
    else
      @js_subtype = nil
    end
    @value = raw_object['value']

    group.add self

    initialize_modules
  end

  def initialize_modules
  end
  private :initialize_modules

  # Registers a module initializer.
  def self.initializer(name)
    before_name = :"initialize_modules_before_#{name}"
    alias_method before_name, :initialize_modules
    private before_name
    remove_method :initialize_modules
    eval <<END_METHOD
      def initialize_modules
        #{name}
        #{before_name.to_s}
      end
END_METHOD
    private :initialize_modules
  end

  # Informs this object that it was released as part of a group release.
  #
  # @private Called by JsObjectGroup#release_all.
  def released!
    @released = true
    @group = nil
  end
end  # class WebkitRemote::Client::JsObject

# Tracks the remote objects in a group (think memory pool).
class JsObjectGroup
  # @return [String] the name of the group of remote objects
  attr_reader :name

  # @return [WebkitRemote::Client] remote debugging client for the browser tab
  #     that owns the objects in this group
  attr_reader :client

  # @return [Boolean] true if the objects in this group were already released
  attr_reader :released
  alias_method :released?, :released

  # Releases all the remote objects in this group.
  #
  # @return [Webkit::Client::JsObjectGroup] self
  def release_all
    return if @objects.empty?

    if @name == nil
      # This is the special group that contains un-grouped objects.
      @objects.values.each do |object|
        object.release
      end
    else
      @client.rpc.call 'Runtime.releaseObjectGroup', objectGroup: name
    end

    @released = true
    @objects.each_value { |object| object.released! }
    @objects.clear
    @client.object_group_remove self
    self
  end

  # Checks if a remote object was allocated in this group.
  #
  # @param [WebkitRemote::Client] object
  # @return [Boolean] true if the object belongs to this group, so releasing
  #     the group would get the object released
  def include?(object)
    @objects[object.remote_id] == object
  end

  # Creates a wrapper for a group of remote objects.
  #
  # @private Use WebkitRemote::Client::Runtime#remote_eval instead of calling
  #     this directly.
  #
  # @param [String] name name of this group of remote objects
  # @param [WebkitRemote::Client] client remote debugging client for the
  #     browser tab that owns the objects in this group
  def initialize(name, client)
    @name = name
    @client = client
    # TODO(pwnall): turn @objects into a set once equality is working
    @objects = {}
    @released = false
  end

  # Registers a remote object that belongs to this group.
  #
  # @private Use WebkitRemote::Client::Runtime#remote_eval instead of calling
  #     this directly.
  #
  # @param [WebkitRemote::Client::JsObject] object the object to be added
  #     to this group
  # @return [WebkitRemote::Client::JsObjectGroup] self
  def add(object)
    if @released
      raise RuntimeError, 'Remote object group already released'
    end
    @objects[object.remote_id] = object
    self
  end

  # Removes a remote object that was individually released.
  #
  # @private Use WebkitRemote::Client::JsObject#release instead of calling
  #     this directly
  #
  # @param [WebkitRemote::Client::JsObject] object the object that will be
  #     removed from the group
  # @return [WebkitRemote::Client::JsObjectGroup] self
  def remove(object)
    @objects.delete object.remote_id
    if @objects.empty?
      @released = true
      @client.object_group_remove self
    end
    self
  end

  # Returns the object in this group with a given id.
  #
  # This helps avoid creating multiple wrappers for the same object.
  #
  # @param [String] remote_id the id to look for
  # @return [WebkitRemote::Client::JsObject, nil] nil if there is no object
  #     whose remote_id matches the method's parameter
  def get(remote_id)
    @objects.fetch remote_id, nil
  end
end  # class WebkitRemote::Client::JsObjectGroup

# A property of a remote JavaScript object.
class JsProperty
  # @return [String] the property's name
  attr_reader :name

  # @return [WebkitRemote::Client::JsObject, Boolean, Number, String, nil]
  #     a Ruby wrapper for the property's value; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by JsObject
  #     instances
  attr_reader :value

  # @return [Boolean] true if JavaScript code can remove this property
  attr_reader :configurable
  alias_method :configurable?, :configurable

  # @return [Boolean] true if JavaScript code can enumerate this property
  attr_reader :enumerable
  alias_method :enumerable?, :enumerable

  # @return [Boolean] true if JavaScript code can change this property's value
  attr_reader :writable
  alias_method :writable?, :writable

  # @return [WebkitRemote::JsObject] the object that this property belongs
  #     to
  attr_reader :owner

  # @param [Hash<String, Object>] raw_property a PropertyDescriptor instance,
  #     according to the Webkit remote debugging protocol; this is an item in
  #     the array returned by the 'Runtime.getProperties' RPC call
  # @param [WebkitRemote::Client::JsObject] owner the object that this
  #     property belongs to
  def initialize(raw_property, owner)
    # NOTE: these are only used at construction time
    client = owner.client
    group_name = owner.group.name

    @owner = owner
    @name = raw_property['name']
    @configurable = !!raw_property['configurable']
    @enumerable = !!raw_property['enumerable']
    @writable = !!raw_property['writable']
    @js_getter = raw_property['get'] && WebkitRemote::Client::JsObject.for(
        raw_property['get'], client, group_name)
    @js_setter = raw_property['set'] && WebkitRemote::Client::JsObject.for(
        raw_property['set'], client, group_name)
    @value = raw_property['value'] && WebkitRemote::Client::JsObject.for(
        raw_property['value'], client, group_name)
  end

  # Debugging output.
  def inspect
    result = self.to_s
    result[-1, 0] =
        " name=#{@name.inspect} configurable=#{@configurable} " +
        "enumerable=#{@enumerable} writable=#{@writable}"
    result
  end
end  # class WebkitRemote::Client::JsProperty

# The call stack that represents the context of an assertion or error.
class StackTrace
  # Parses a StackTrace object returned by a RPC request.
  #
  # @param [Array<String, Object>] raw_stack_trace the raw StackTrace object
  #     in the Runtime domain returned by an RPC request
  def initialize(raw_stack_trace)
    @description = raw_stack_trace['description']
    @frames = raw_stack_trace['callFrames'].map do |raw_frame|
      frame = {}
      if raw_frame['columnNumber']
        frame[:column] = raw_frame['columnNumber'].to_i
      end
      if raw_frame['lineNumber']
        frame[:line] = raw_frame['lineNumber'].to_i
      end
      if raw_frame['functionName']
        frame[:function] = raw_frame['functionName']
      end
      if raw_frame['url']
        frame[:url] = raw_frame['url']
      end
      frame
    end

    parent_trace = raw_stack_trace['parent']
    if parent_trace
      @parent = StackTrace.new parent_trace
    else
      @parent = nil
    end
  end

  # @return [String] label of the trace; for async traces, might be the name of
  #      a function that initiated the async call
  attr_reader :description

  # @return [Array<Symbol, Object>] Ruby-friendly stack trace
  attr_reader :frames

  # @return [WebkitRemote::Client::StackTrace] stack trace for a parent async
  #     call; may be null
  attr_reader :parent

  # Parses a StackTrace object returned by a RPC request.
  #
  # @param [Array<String, Object>] raw_stack_trace the raw StackTrace object
  #     in the Runtime domain returned by an RPC request
  # @return [WebkitRemote::Client::StackTrace]
  def self.parse(raw_stack_trace)
    return nil unless raw_stack_trace

    StackTrace.new raw_stack_trace
  end
end  # class WebkitRemote::Client::StackTrace

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
