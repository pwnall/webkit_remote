require 'json'
require 'ws_sync_client'

module WebkitRemote

# RPC client for the Webkit remote debugging protocol.
class Rpc
  # Connects to the remote debugging server in a Webkit tab.
  #
  # @param [Hash] opts info on the tab to connect to
  # @option opts [WebkitRemote::Tab] tab reference to the tab whose debugger
  #     server this RPC client connects to
  def initialize(opts = {})
    unless tab = opts[:tab]
      raise ArgumentError, 'Target tab not specified'
    end
    @closed = false
    @next_id = 2
    @events = []

    @debug_url = tab.debug_url
    @web_socket = WsSyncClient.new @debug_url
  end

  # Remote debugging RPC call.
  #
  # See the following URL for implemented calls.
  #     https://developers.google.com/chrome-developer-tools/docs/protocol/1.1/index
  #
  # @param [String] method name of the RPC method to be invoked
  # @param [Hash<String, Object>, nil] params parameters for the RPC method to
  #     be invoked
  # @return [Hash<String, Object>] the return value of the RPC method
  def call(method, params = nil)
    request_id = @next_id
    @next_id += 1
    request = {
      jsonrpc: '2.0',
      id: request_id,
      method: method,
    }
    request[:params] = params if params
    request_json = JSON.dump request
    @web_socket.send_frame request_json

    loop do
      result = receive_message request_id
      return result if result
    end
  end

  # Continuously reports events sent by the remote debugging server.
  #
  # @yield once for each RPC event received from the remote debugger; break to
  #     stop the event listening loop
  # @yieldparam [Hash<Symbol, Object>] event the name and information hash of
  #     the event, under the keys :name and :data
  # @return [WebkitRemote::Rpc] self
  def each_event
    loop do
      if @events.empty?
        receive_message nil
      else
        yield @events.shift
      end
    end
    self
  end

  # Closes the connection to the remote debugging server.
  #
  # Call this method to avoid leaking resources.
  #
  # @return [WebkitRemote::Rpc] self
  def close
    return if @closed
    @closed = true
    @web_socket.close
    @web_socket = nil
    self
  end

  # @return [Boolean] if true, the connection to the remote debugging server
  #     has been closed, and this instance is mostly useless
  attr_reader :closed
  alias_method :closed?, :closed

  # @return [String] points to this client's Webkit remote debugging server
  attr_reader :debug_url

  # Blocks until a WebKit message is received, then parses it.
  #
  # RPC notifications are added to the @events array.
  #
  # @param [Integer, nil] expected_id if a RPC response is expected, this
  #     argument has the response id; otherwise, the argument should be nil
  # @return [Hash<String, Object>, nil] a Hash containing the RPC result if an
  #     expected RPC response was received; nil if an RPC notice was received
  def receive_message(expected_id)
    json = @web_socket.recv_frame
    begin
      data = JSON.parse json
    rescue JSONError
      close
      raise RuntimeError, 'Invalid JSON received'
    end
    if data['id']
      # RPC result.
      if data['id'] != expected_id
        close
        raise RuntimeError, 'Out of sequence RPC response id'
      end
      if data['error']
        code = data['error']['code']
        message = data['error']['message']
        raise RuntimeError, "RPC Error #{code}: #{message}"
      end
      return data['result']
    elsif data['method']
      # RPC notice.
      event = { name: data['method'], data: data['params'] }
      @events << event
      return nil
    else
      close
      raise RuntimeError, "Unexpected / invalid RPC message #{data.inspect}"
    end
  end
  private :receive_message
end  # class WebkitRemote::Rpc

end  # namespace WebkitRemote
