module WebkitRemote

# An event received via a RPC notification from a Webkit remote debugger.
#
# This is a generic super-class for events.
class Event
  # Wrap raw event data received via a RPC notification.
  #
  # @param [Hash] rpc_event event information yielded by a call to
  #     WebkitRemote::Rpc.each_event
  def initialize(rpc_event)
    @name = rpc_event[:name]
    @domain = rpc_event[:name].split('.', 2).first
    @raw_data = rpc_event[:raw_data]
  end

  # @return [String] event's domain, e.g. "Page", "DOM".
  attr_reader :domain

  # @return [String] event's name, e.g. "Page.loadEventFired".
  attr_reader :name
end  # class WebkitRemote::Event

end  # namespace WebkitRemote
