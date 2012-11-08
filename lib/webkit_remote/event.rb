module WebkitRemote

# An event received via a RPC notification from a Webkit remote debugger.
#
# This is a generic super-class for events.
class Event
  # @return [String] event's domain, e.g. "Page", "DOM".
  attr_reader :domain

  # @return [String] event's name, e.g. "Page.loadEventFired".
  attr_reader :name

  # @return [Hash<String, Object>] the raw event information provided by the
  #     RPC client
  attr_reader :raw_data

  # Checks if the event meets a set of conditions.
  #
  # This is used in WebkitRemote::Client#wait_for.
  #
  # @param [Hash<Symbol, Object>] conditions the conditions that must be met
  #     by an event to get out of the waiting loop
  # @option conditions [Class] class the class of events to wait for; this
  #     condition is met if the event's class is a sub-class of the given class
  # @option conditions [Class] type synonym for class that can be used with the
  #     Ruby 1.9 hash syntax
  # @option conditions [String] name the event's name, e.g.
  #     "Page.loadEventFired"
  # @return [Boolean] true if this event matches all the given conditions
  def matches?(conditions)
    conditions.all? do |key, value|
      case key
      when :class, :type
        kind_of? value
      when :name
        name == value
      else
        # Simple cop-out.
        send(key) == value
      end
    end
  end

  # Checks if a client can possibly meet an event meeting the given conditions.
  #
  # @private This is used by Client#wait_for to prevent hard-to-find bugs.
  #
  # @param [WebkitRemote::Client] client the client to be checked
  # @param (see WebkitRemote::Event#matches?)
  # @return [Boolean] false if calling WebkitRemote::Client#wait_for with the
  #     given conditions would get the client stuck
  def self.can_receive?(client, conditions)
    conditions.all? do |key, value|
      case key
      when :class, :type
        value.can_reach?(client)
      when :name
        class_for(value).can_reach?(client)
      else
        true
      end
    end
  end

  # Wraps raw event data received via a RPC notification.
  #
  # @param [Hash<Symbol, Object>] rpc_event event information yielded by a call
  #     to WebkitRemote::Rpc.each_event
  # @param [WebkitRemote::Client] the client that received this message
  # @return [WebkitRemote::Event] an instance of an Event subclass that best
  #     represents the given event
  def self.for(rpc_event, client)
    klass = class_for rpc_event[:name]
    klass.new rpc_event, client
  end

  # The WebkitRemote::Event subclass registered to handle an event.
  #
  # @private Use WebkitRemote::Event#for instead of calling this directly.
  #
  # @param [String] rpc_event_name the value of the 'name' property of an event
  #     notice received via the remote debugging RPC
  # @return [Class] WebkitRemote::Event or one of its subclasses
  def self.class_for(rpc_event_name)
    @registry[rpc_event_name] || Event
  end

  # Wraps raw event data received via a RPC notification.
  #
  # @private API clients should use Event#for instead of calling the
  #     constructor directly.
  #
  # If at all possible, subclasses should avoid using the WebkitRemote::Client
  # instance, to avoid tight coupling.
  #
  # @param [Hash<Symbol, Object>] rpc_event event information yielded by a call
  #     to WebkitRemote::Rpc.each_event
  # @param [WebkitRemote::Client] the client that received this message
  def initialize(rpc_event, client)
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

  # Checks if a client is set up to receive an event of this class.
  #
  # @private Use Event# instead of calling this directly.
  #
  # This method is overridden in Event sub-classes. For example, events in the
  # Page domain can only be received if WebkitRemote::Client::Page#page_events
  # is true.
  def self.can_reach?(client)
    true
  end
end  # class WebkitRemote::Event

end  # namespace WebkitRemote
