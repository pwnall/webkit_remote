require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'thread'

module WebkitRemote

# Client for the Webkit remote debugging protocol.
#
# A client manages a single tab.
class Client
  # Connects to the remote debugging server in a Webkit tab.
  #
  # @param [Hash] opts info on the tab to connect to
  # @option opts [WebkitRemote::Tab] tab reference to the tab whose debugger
  #     server this client connects to
  # @option opts [Boolean] close_browser if true, the session to the brower
  #     that the tab belongs to will be closed when this client's connection
  #     is closed
  def initialize(opts = {})
    unless tab = opts[:tab]
      raise ArgumentError, 'Target tab not specified'
    end
    @browser = tab.browser
    @close_browser = opts.fetch :close_browser, false
    @closed = false
    @send_queue = EventMachine::Queue.new
    @recv_queue = Queue.new
    @next_id = 2
    @events = []

    self.class.em_start
    @web_socket = Faye::WebSocket::Client.new tab.debug_url
    setup_web_socket
  end

  # Remote debugging RPC call.
  #
  # See the following URL for implemented calls.
  #     https://developers.google.com/chrome-developer-tools/docs/protocol/1.0/index
  #
  # @param [String] method name of the RPC method to be invoked
  # @param [Hash, nil] params parameters for the RPC method to be invoked
  # @return [Hash] the return value of the RPC method
  def rpc(method, params = nil)
    request_id = @next_id
    @next_id += 1
    request = {
      jsonrpc: '2.0',
      id: request_id,
      method: method,
    }
    request[:params] = params if params
    request_json = JSON.dump request
    @send_queue.push request_json

    loop do
      result = receive_message request_id
      return result if result
    end
  end

  # Continuously reports events sent by the remote debugging server.
  #
  # @yield once for each RPC event received from the remote debugger; break to
  #     stop the event listening loop
  # @yieldparam [Hash] event the name and information hash of the event, under
  #     the keys :name and :data
  def each_event
    loop do
      if @events.empty?
        receive_message nil
      else
        yield @events.shift
      end
    end
  end

  # Closes the remote debugging connection.
  #
  # Call this method to avoid leaking resources.
  def close
    return if @closed
    @closed = true
    @web_socket.close
    @browser.close if @close_browser
    self.class.em_stop
  end

  # @return [Boolean] if true, the connection to the remote debugging server
  #     has been closed, and this instance is mostly useless
  attr_reader :closed
  alias_method :closed?, :closed

  # @return [Boolean] if true, the master debugging connection to the browser
  #     associated with the client's tab will be closed; in turn, this might
  #     stop the browser process
  attr_accessor :close_browser
  alias_method :close_browser?, :close_browser

  # Hooks up the event handlers of the WebSocket remote debugging client.
  def setup_web_socket
    @web_socket.onopen = lambda do |event|
      send_request
      @web_socket.onmessage = lambda do |event|
        data = event.data
        EventMachine.defer do
          @recv_queue.push data
        end
      end
      @web_socket.onclose = lambda do |event|
        code = event.code
        EventMachine.defer do
          @recv_queue.push code
        end
      end
    end
  end
  private :setup_web_socket

  # One iteration of the request sending loop.
  #
  # RPC requests are JSON-serialized on the sending thread, then pushed into
  # the send queue, which is an EventMachine queue. On the reactor thread, the
  # serialized message is sent as a WebSocket frame.
  def send_request
    @send_queue.pop do |json|
      @web_socket.send json
      send_request
    end
  end
  private :send_request

  # Blocks until a WebKit message is received, then parses it.
  #
  # RPC notifications are added to the @events array.
  #
  # @param [Integer, nil] expected_id if a RPC response is expected, this
  #     argument has the response id; otherwise, the argument should be nil
  # @return [Hash, nil] a Hash containing the RPC result if an expected RPC
  #     response was received; nil if an RPC notice was received
  def receive_message(expected_id)
    json = @recv_queue.pop
    unless json.respond_to? :to_str
      raise RuntimeError, 'The server closed the WebSocket'
    end
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
        raise RuntimeError, "Error #{data['error']['code']}"
      end
      return data['result']
    elsif data['method']
      # RPC notice.
      event = { name: data['method'], data: data['params'] }
      @events << event
      return nil
    else
      close
      raise RuntimeError, "Invalid JSON RPC message #{data.inspect}"
    end
  end
  private :receive_message

  # Sets up an EventMachine reactor if necessary.
  def self.em_start
    if @em_clients == 0
      em_ready_lock = Mutex.new
      em_ready = ConditionVariable.new
      @em_thread = Thread.new do
        EventMachine.run do
          em_ready_lock.synchronize { em_ready.signal }
        end
      end
      em_ready_lock.synchronize { em_ready.wait em_ready_lock }
    end
    @em_clients += 1
  end
  @em_clients = 0
  @em_thread = nil

  # Shuts down an EventMachine reactor if necessary.
  def self.em_stop
    @em_clients -= 1
    if @em_clients == 0
      if @em_thread
        EventMachine.stop_event_loop
        EventMachine.reactor_thread.join
        @em_thread.join
      end
      @em_thread = nil
    end
  end
end  # class WebkitRemote::Client

end  # namespace webkitRemote
