module WebkitRemote

class Client

# API for the Runtime domain.
module Runtime
  # Evals a JavaScript expression.
  #
  # @param [String] expression the JavaScript expression to be evaluated
  # @param [String, Symbol] group the name of an object group (think memory
  #     pools); the objects in a group can be released together in a single
  #     call
  # @return [WebkitRemote::Client::RemoteObject] self
  def evaluate()
    # NOTE: returnByValue is always set to true to avoid some extra complexity
    raw_object = @rpc.call 'Runtime.evaluate', script: script,
        objectGroup: group || '_', returnByValue: true
    WebkitRemote::Client::RemoteObject.new raw_object, self
  end
end  # module WebkitRemote::Client::Runtime

# Mirrors a RemoteObject, defined in the Runtime domain.
class RemoteObject
  #
  def initialize(raw_object, client)
    @client = client
  end
end  # class WebkitRemote::Client::RemoteObject

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
