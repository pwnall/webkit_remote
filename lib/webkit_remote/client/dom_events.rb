module WebkitRemote

class Event

# Emitted when the entire document has changed, and all DOM structure is lost.
class DomReset < WebkitRemote::Event
  register 'Dom.documentUpdated'

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    client.clear_dom
  end
end  # class WebkitRemote::Event::DomReset

end  # namespace WebkitRemote::Event

end  # namepspace WebkitRemote
