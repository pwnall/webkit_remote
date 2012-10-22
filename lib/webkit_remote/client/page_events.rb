module WebkitRemote

class Event

# Emitted when a page's load event is triggerred.
class PageLoaded < WebkitRemote::Event
  def initialize(rpc_event)
    super
    @timestamp = raw_data['timestamp']
  end

  # @return [Number] the event timestamp
  attr_reader :timestamp
end  # class WebkitRemote::Event::PageLoaded

end  # namespace WebkitRemote::Event

end  # namepspace WebkitRemote
