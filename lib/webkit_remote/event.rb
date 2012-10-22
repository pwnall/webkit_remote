module WebkitRemote

# An event received via a RPC notification from a Webkit remote debugger.
#
# This is a generic super-class for events.
class Event
  # Wraps raw event data received via a RPC notification.
  #
  # @param [Hash<Symbol, Object>] rpc_event event information yielded by a call
  #     to WebkitRemote::Rpc.each_event
  # @return [WebkitRemote::Event] an instance of an Event subclass that best
  #     represents the given event
  def self.for(rpc_event)
    klass = @registry[rpc_event[:name]] || Event
    klass.new rpc_event
  end

  # @return [String] event's domain, e.g. "Page", "DOM".
  attr_reader :domain

  # @return [String] event's name, e.g. "Page.loadEventFired".
  attr_reader :name

  # @return [Hash<String, Object>] the raw event information provided by the
  #     RPC client
  attr_reader :raw_data

  # Wraps raw event data received via a RPC notification.
  #
  # @private API clients should use Event#for instead of calling the
  #     constructor directly.
  #
  # @param [Hash<Symbol, Object>] rpc_event event information yielded by a call
  #     to WebkitRemote::Rpc.each_event
  def initialize(rpc_event)
    @name = rpc_event[:name]
    @domain = rpc_event[:name].split('.', 2).first
    @raw_data = rpc_event[:data] || {}
  end

  # Registers an Event sub-class for to be instantiated when parsing an event.
  #
  # @private Only Event sub-classes should use this API.
  #
  # @param [String] name fully qualified event name, e.g. "Page.loadEventFired"
  # @return [Class] self
  def self.register(name)
    WebkitRemote::Event.register_class self, name
    self
  end

  # Registers an Event sub-class for to be instantiated when parsing an event.
  #
  # @private Event sub-classes should call #register on themselves instead of
  #     calling this directly.
  #
  # @param [String] klass the Event subclass to be registered
  # @param [String] name fully qualified event name, e.g. "Page.loadEventFired"
  # @return [Class] self
  def self.register_class(klass, name)
    if @registry.has_key? name
      raise ArgumentError, "#{@registry[name].name} already registered #{name}"
    end
    @registry[name] = klass
    self
  end
  @registry = {}
end  # class WebkitRemote::Event

end  # namespace WebkitRemote
