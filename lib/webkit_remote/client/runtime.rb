module WebkitRemote

class Client

# API for the Runtime domain.
module Runtime
  # Evals a JavaScript expression.
  #
  # @param [String] expression the JavaScript expression to be evaluated
  # @param [Hash] opts tweaks
  # @option opts [String] group the name of an object group (think memory
  #     pools); the objects in a group can be released together by one call to
  #     WebkitRemote::Client::RemoteObjectGroup#release
  # @return [WebkitRemote::Client::RemoteObject] self
  def remote_eval(expression, opts = {})
    # NOTE: returnByValue is always set to true to avoid some extra complexity
    raw_object = @rpc.call 'Runtime.evaluate', script: script,
        objectGroup: group || '_', returnByValue: true
    WebkitRemote::Client::RemoteObject.new raw_object, self
  end

  # Retrieves a group of remote objects by its name.
  #
  # @param [String] group_name name given to remote_eval when the object was
  #     created
  # @param [Boolean] create if true, fetching a group that does not exist will
  #     create the group; this parameter should only be used internally
  # @return [WebkitRemote::Client::RemoteObjectGroup, nil] wrapper for the
  #     group with the given name, or nil if no such group exists (the group
  #     might have been released)
  def object_group(group_name, create = false)
    group = @runtime_groups[group_name]
    return group if group
    create? WebkitRemote::Client::RemoteObjectGroup.new(group_name, self) : nil
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
  initializer :initialize_runtime
end  # module WebkitRemote::Client::Runtime

# Mirrors a RemoteObject, defined in the Runtime domain.
class RemoteObject
  #
  attr_reader :remote_id

  # @return [WebkitRemote::Client] remote debugging client for the browser tab
  #     that owns the objects in this group
  attr_reader :client

  # @return [Boolean] true if the objects in this group were already released
  attr_reader :released
  alias_method :released?, :released

  # Releases this remote object on the browser side.
  #
  # @return [Webkit::Client::RemoteObject] self
  def release
    if @released
      raise RuntimeError, 'Remote object already released'
    end
    @rpc.call 'Runtime.releaseObject', objectId: @remote_id
    @released = true
    @group.remove self
  end

  # Wraps a raw object returned by the Webkit remote debugger RPC protocol.
  #
  # @private Use WebkitRemote::Client::Runtime#remote_eval instead of calling
  #     this directly.
  #
  # @param [Hash<String, Object>] raw_object return value of a
  #     'Runtime.evaluate' RPC call
  # @param [WebkitRemote::Client::Runtime] client remote debugging client for
  #     the browser tab that owns this object
  # @param [String[ group_name name of the object group that will hold this
  #     object; object groups work like memory pools
  def self.for(raw_object, client, group_name)
    if raw_object['object_id']
      group = client.object_group group_name, true
      object = WebkitRemote::Client::RemoteObject.new raw_object, group
    else
      # primitive types
      case raw_object['type'].to_sym
      when :boolean, :number, :string
        return raw_object['value']
      when :undefined
        # TODO(pwnall): Not sure what to do here.
      when :function
        # TODO(pwnall): Not sure what to do here.
      when :object
        # TODO(pwnall): Figure this out.
      end
    end
  end

  # Wraps a remote JavaScript object
  #
  # @private RemoteObject#for should be used instead of this, as it handles
  #   some edge cases
  def initialize(raw_object, client, group)
    @client = client
    @rpc = client.rpc
    @group = group

    @remote_id = raw_object['objectId']
    @js_class_name = raw_object['className']
    @description = raw_object['description']
    @js_type = raw_object['type'].to_sym
    @js_subtype = raw_object['subtype'].to_sym
    @value = raw_object['value']

    group.add self
  end

  # Informs this object that it was released as part of a group release.
  #
  # @private Called by RemoteObjectGroup#release_all.
  def released!
    @released = true
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
    @rpc.call 'Runtime.releaseObjectGroup', objectGroup: name
    @released = true
    @objects.each_value { |object| object.released! }
    @objects.clear
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
  # @param [WebkitRemote::Client::RemoteObject] the object to be added to this
  #     group
  def add(object)
    if @released
      raise RuntimeError, 'Remote object group already released'
    end
    @objects[object.remote_id] = object
  end

  # Removes a remote object that was individually released.
  #
  # @private Use WebkitRemote::Client::RemoteObject#release instead of calling
  #     this directly
  def remove(object)
    @objects.delete object.remote_id
  end
end  # class WebkitRemote::Client::RemoteObjectGroup

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
