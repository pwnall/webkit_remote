module WebkitRemote

# Client for the Webkit remote debugging protocol
#
# A client manages a single tab.
class Client
  # Connects to the remote debugging server in a Webkit tab.
  #
  # @param [Hash] opts info on the tab to connect to
  # @option opts [WebkitRemote::Tab] tab reference to the tab whose debugger
  #     server this RPC client connects to
  # @option opts [Boolean] close_browser if true, the session to the brower
  #     that the tab belongs to will be closed when this RPC client's
  #     connection is closed
  def initialize(opts = {})
    unless tab = opts[:tab]
      raise ArgumentError, 'Target tab not specified'
    end
    @rpc = WebkitRemote::Rpc.new opts
    @browser = tab.browser
    @close_browser = opts.fetch :close_browser, false
    @closed = false
  end

  # Closes the remote debugging connection.
  #
  # Call this method to avoid leaking resources.
  #
  # @return [WebkitRemote::Rpc] self
  def close
    return if @closed
    @closed = true
    @rpc.close
    @rpc = nil
    @browser.close if @close_browser
    self
  end

  # @return [Boolean] if true, the connection to the remote debugging server
  #     has been closed, and this instance is mostly useless
  attr_reader :closed
  alias_method :closed?, :closed

  # @return [Boolean] if true, the master debugging connection to the browser
  #     associated with the client's tab will be automatically closed when this
  #     RPC client's connection is closed; in turn, this might stop the browser
  #     process
  attr_accessor :close_browser
  alias_method :close_browser?, :close_browser

  # Continuously reports events sent by the remote debugging server.
  #
  # @yield once for each RPC event received from the remote debugger; break to
  #     stop the event listening loop
  # @yieldparam [WebkitRemote::Event] event an instance of an Event sub-class
  #     that best represents the received event
  # @return [WebkitRemote::Client] self
  def each_event
    @rpc.each_event do |rpc_event|
      yield WebkitRemote::Event.for(rpc_event)
    end
    self
  end

  # @return [WebkitRemote::Rpc] the WebSocket RPC client; useful for making raw
  #     RPC calls to unsupported methods
  attr_reader :rpc

  # @return [WebkitRemote::Browser] master session to the browser that owns the
  #     tab debugged by this client
  attr_reader :browser

  include WebkitRemote::Client::Page
end  # class WebkitRemote::Client

end  # namespace WebkitRemote
