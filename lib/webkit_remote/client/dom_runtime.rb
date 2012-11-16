module WebkitRemote

class Client

class JsObject
  # @return [WebkitRemote::Client::DomNode] the DOM node wrapped by this
  #     JavaScript object
  def dom_node
    @dom_node ||= dom_node!
  end

  # Fetches the wrapped DOM node, bypassing the object's cache.
  #
  # @return [WebkitRemote::Client::DomNode] the DOM domain object wrapped by
  #     this JavaScript object
  def dom_node!
    result = @client.rpc.call 'DOM.requestNode', objectId: @remote_id
    @dom_node = if result['nodeId']
      @client.dom_node result['nodeId']
    else
      nil
    end
  end

  # @private Called by the JsObject constructor.
  def initialize_dom
    @dom_node = nil
  end
  initializer :initialize_dom
end  # class WebkitRemote::Client::JsObject

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
