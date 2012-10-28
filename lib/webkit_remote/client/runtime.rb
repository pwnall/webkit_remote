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
  #     call to WebkitRemote::Client::RemoteObjectGroup#release
  # @return [WebkitRemote::Client::RemoteObject, Boolean, Number, String] the
  #     result of evaluating the expression
  def remote_eval(expression, opts = {})
    group_name = opts[:group] || '_'
    # NOTE: returnByValue is always set to false to avoid some extra complexity
    result = @rpc.call 'Runtime.evaluate', expression: expression,
                       objectGroup: group_name
    object = WebkitRemote::Client::RemoteObject.for result['result'], self,
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
  #     object was created
  # @param [Boolean] create if true, fetching a group that does not exist will
  #     create the group; this parameter should only be used internally
  # @return [WebkitRemote::Client::RemoteObject, Boolean, Number, String, nil]
  #     a Ruby wrapper for the evaluation result; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by RemoteObject
  #     instances
  def object_group(group_name, create = false)
    group_name = group_name.to_s
    group = @runtime_groups[group_name]
    return group if group
    if create
      @runtime_groups[group_name] =
          WebkitRemote::Client::RemoteObjectGroup.new(group_name, self)
    else
      nil
    end
  end

  # Removes a group from the list of tracked groups.
  #
  # @private Use WebkitRemote::Client::RemoteObjectGroup#release instead of
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
end  # module WebkitRemote::Client::Runtime

initializer :initialize_runtime
include Runtime

# Mirrors a RemoteObject, defined in the Runtime domain.
class RemoteObject
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

  # @return [WebkitRemote::Client::RemoteObjectGroup] the group that contains
  #     this object; the object can be released by calling release_all on the
  #     group
  attr_reader :group

  # @return [String] identifies this object in the remote debugger
  # @private Use the RemoteObject methods instead of calling this directly.
  attr_reader :remote_id

  # Releases this remote object on the browser side.
  #
  # @return [Webkit::Client::RemoteObject] self
  def release
    return if @released
    @rpc.call 'Runtime.releaseObject', objectId: @remote_id
    @group.remove self
    released!
  end

  # This object's properties.
  #
  # If the object's properties have not been retrieved, this method retrieves
  # them via a RPC call.
  #
  # @return [Hash<Symbol, Webkit::Client::RemoteProperty>] frozen Hash containg
  #     the object's properties
  def properties
    @properties || properties!
  end

  # This object's properties, guaranteed to be fresh.
  #
  # This method always reloads the object's properties via a RPC call.
  #
  # @return [Hash<Symbol, Webkit::Client::RemoteProperty>] frozen Hash containg
  #     the object's properties
  def properties!
    result = @rpc.call 'Runtime.getProperties', objectId: @remote_id
    @properties = Hash[
      result['result'].map do |raw_property|
        property = WebkitRemote::Client::RemoteProperty.new raw_property, self
        [property.name, property]
      end
    ].freeze
  end

  # Calls a method on this object.
  #
  # @param [String] method the name of the method to be called
  # @param [Array<WebkitRemote::Client::Object, String, Number, Boolean, nil>]
  #     args the arguments passed to the function
  # @return [WebkitRemote::Client::RemoteObject, Boolean, Number, String, nil]
  #     a Ruby wrapper for the given raw object; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by RemoteObject
  #     instances
  def call(method, *args)
    call_args = args.map do |arg|
      if arg.kind_of? WebkitRemote::Client::RemoteObject
        { objectId: arg.remote_id }
      else
        { value: arg }
      end
    end
    result = @rpc.call 'Runtime.callFunctionOn', objectId: @remote_id,
        functionDeclaration: method, arguments: call_args, returnByValue: false
    object = WebkitRemote::Client::RemoteObject.for result['result'], @client,
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
  # @param [Hash<String, Object>] raw_object a RemoteObject instance, according
  #     to the Webkit remote debugging protocol; this is the return value of a
  #     'Runtime.evaluate' RPC call
  # @param [WebkitRemote::Client::Runtime] client remote debugging client for
  #     the browser tab that owns this object
  # @param [String] group_name name of the object group that will hold this
  #     object; object groups work like memory pools
  # @return [WebkitRemote::Client::RemoteObject, Boolean, Number, String] a
  #     Ruby wrapper for the given raw object; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by RemoteObject
  #     instances
  def self.for(raw_object, client, group_name)
    if remote_id = raw_object['objectId']
      group = client.object_group group_name, true
      return group.get(remote_id) ||
             WebkitRemote::Client::RemoteObject.new(raw_object, group)
    else
      # primitive types
      case raw_object['type'] ? raw_object['type'].to_sym : nil
      when :boolean, :number, :string
        return raw_object['value']
      when :undefined
        # TODO(pwnall): Not sure what to do here.
      when :function
        # TODO(pwnall): Not sure what to do here.
      when :object
        case raw_object['subtype'] ? raw_object['subtype'].to_sym : nil
        when :null
          return nil
        end
        # TODO(pwnall): Figure this out.
      end
    end
    raise RuntimeError, "Unable to parse #{raw_object.inspect}"
  end

  # Wraps a remote JavaScript object
  #
  # @private RemoteObject#for should be used instead of this, as it handles
  #     some edge cases
  def initialize(raw_object, group)
    @group = group
    @client = group.client
    @rpc = client.rpc
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
  end

  # Informs this object that it was released as part of a group release.
  #
  # @private Called by RemoteObjectGroup#release_all.
  def released!
    @released = true
    @group = nil
  end
end  # class WebkitRemote::Client::RemoteObject

# Tracks the remote objects in a group (think memory pool).
class RemoteObjectGroup
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
  # @return [Webkit::Client::RemoteObjectGroup] self
  def release_all
    return if @objects.empty?
    @rpc.call 'Runtime.releaseObjectGroup', objectGroup: name
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
    @rpc = client.rpc
    # TODO(pwnall): turn @objects into a set once equality is working
    @objects = {}
    @released = false
  end

  # Registers a remote object that belongs to this group.
  #
  # @private Use WebkitRemote::Client::Runtime#remote_eval instead of calling
  #     this directly.
  #
  # @param [WebkitRemote::Client::RemoteObject] object the object to be added
  #     to this group
  # @return [WebkitRemote::Client::RemoteObjectGroup] self
  def add(object)
    if @released
      raise RuntimeError, 'Remote object group already released'
    end
    @objects[object.remote_id] = object
    self
  end

  # Removes a remote object that was individually released.
  #
  # @private Use WebkitRemote::Client::RemoteObject#release instead of calling
  #     this directly
  #
  # @param [WebkitRemote::Client::RemoteObject] object the object that will be
  #     removed from the group
  # @return [WebkitRemote::Client::RemoteObjectGroup] self
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
  # @return [WebkitRemote::Client::RemoteObject, nil] nil if there is no object
  #     whose remote_id matches the method's parameter
  def get(remote_id)
    @objects.fetch remote_id, nil
  end
end  # class WebkitRemote::Client::RemoteObjectGroup

# A property of a remote JavaScript object.
class RemoteProperty
  # @return [Symbol] the
  attr_reader :name

  # @return [WebkitRemote::Client::RemoteObject, Boolean, Number, String, nil]
  #     a Ruby wrapper for the property's value; primitives get wrapped by
  #     standard Ruby classes, and objects get wrapped by RemoteObject
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

  # @return [WebkitRemote::RemoteObject] the object that this property belongs
  #     to
  attr_reader :owner

  # @param [Hash<String, Object>] raw_property a PropertyDescriptor instance,
  #     according to the Webkit remote debugging protocol; this is an item in
  #     the array returned by the 'Runtime.getProperties' RPC call
  # @param [WebkitRemote::Client::RemoteObject] owner the object that this
  #     property belongs to
  def initialize(raw_property, owner)
    # NOTE: these are only used at construction time
    client = owner.client
    group_name = owner.group.name

    @owner = owner
    @name = raw_property['name'].to_sym
    @configurable = !!raw_property['configurable']
    @enumerable = !!raw_property['enumerable']
    @writable = !!raw_property['writable']
    @js_getter = raw_property['get'] && WebkitRemote::Client::RemoteObject.for(
        raw_property['get'], client, group_name)
    @js_setter = raw_property['set'] && WebkitRemote::Client::RemoteObject.for(
        raw_property['set'], client, group_name)
    @value = raw_property['value'] && WebkitRemote::Client::RemoteObject.for(
        raw_property['value'], client, group_name)
  end
end  # class WebkitRemote::Client::RemoteProperty

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
