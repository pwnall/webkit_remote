require 'json'
require 'net/http'

module WebkitRemote

# The master connection to the remote debugging server in a Webkit process.
class Browser
  # Sets up a debugging connection to a Webkit processr.
  #
  # @param [Hash] opts info on the browser to connect to
  # @option opts [String] host the hostname / IP address of the Webkit remote
  #     debugging server
  # @option opts [Integer] port the port that the Webkit remote debugging
  #     server listens to
  # @option opts [WebkitRemote::Process] process a process on the local machine
  #     to connect to; the process will automatically be stopped when the
  #     debugging connection is closed; the host and port will be configured
  #     automatically
  # @option opts [Boolean] stop_process if true, the WebkitRemote::Process
  #     passed to the constructor will be automatically stopped
  # @raise [SystemCallError] if the connection could not be established; this
  #     most likely means that there is no remote debugging server at the given
  #     host / port
  def initialize(opts = {})
    if opts[:process]
      @process = opts[:process]
      @stop_process = opts.fetch :stop_process, false
      @host = 'localhost'
      @port = process.port
    else
      @process = nil
      @stop_process = false
      @host = opts[:host] || 'localhost'
      @port = opts[:port] || 9292
    end
    @closed = false

    @http = Net::HTTP.start @host, @port
  end

  # Closes the connection the browser.
  #
  # If the Browser instance was given a WebkitRemote::Process, the process will
  # also be stopped. This instance becomes useless after closing.
  #
  # @return [WebkitRemote::Browser] self
  def close
    return self if @closed
    @closed = true
    @http.finish
    @http = nil
    @process.stop if @stop_process
    self
  end

  # Retrieves the tabs that are currently open in the browser.
  #
  # These tabs can be used to start debugging.
  #
  # @return [Array<WebkitRemote::Browser::Tab>] the open tabs
  def tabs
    http_response = @http.request Net::HTTP::Get.new('/json')
    tabs = JSON.parse(http_response.body).map do |json_tab|
      title = json_tab['title']
      url = json_tab['url']
      debug_url = json_tab['webSocketDebuggerUrl']
      Tab.new self, debug_url, title: title, url: url
    end
  end

  # @return [Boolean] if true, a WebkitRemote::Process will be stopped when
  #     this browser connection is closed
  attr_reader :stop_process
  alias_method :stop_process?, :stop_process

  # Changes the automated WebkitRemote::Process stopping behavior.
  #
  # This should only be set to true if this Browser instance was given a
  # WebkitRemote::Process at creation time.
  #
  # @param [Boolean] new_stop_process if true, the WebkitRemote::Process
  #     passed to this instance's constructor will be stopped when this
  #     connection is closed
  # @return [Boolean] new_stop_process
  def stop_process=(new_stop_process)
    if new_stop_process
      unless @process
        raise ArgumentError, "Browser instance not backed by a Webkit process"
      end
      @stop_process = true
    else
      @stop_process = false
    end
    new_stop_process
  end

  # @return [WebkitRemote::Process, nil] Process instance passed to this
  #     connection's constructor
  attr_reader :process

  # @return [String] hostname or IP of the Webkit remote debugging server
  attr_reader :host

  # @return [Integer] port that the Webkit remote debugging server listens on
  attr_reader :port

  # @return [Boolean] if true, the connection to the remote debugging server
  #     has been closed, and this instance is mostly useless
  attr_reader :closed
  alias_method :closed?, :closed

  # Clean up when garbage collected.
  def finalize
    close unless @closed
  end

# References a tab open in a Webkit process with a remote debugging server.
class Tab
  # @return [Webkit::Remote] connection to the browser that this tab belongs to
  attr_reader :browser

  # @return [String] URL of the tab's remote debugging endpoint
  attr_reader :debug_url

  # @return [String, nil] title of the Web page open in the browser tab
  attr_reader :title

  # @return [String, nil] URL of the Web page open in the browser tab
  attr_reader :url

  # Creates a tab reference.
  #
  # @param [WebkitRemote::Browser] browser the master debugging connection to
  #     the Webkit process
  # @param [String] debug_url URL of the tab's remote debugging endpoint
  # @param [Hash] metadata non-essential information about the tab
  # @option metadata [String, nil] title title of the page open in the browser
  #     tab
  # @option metadata [String, nil] url URL of the page open in the browser tab
  def initialize(browser, debug_url, metadata)
    @browser = browser
    @debug_url = debug_url
    @title = metadata[:title]
    @url = metadata[:url]
  end
end  # class WebkitRemote::Browser::Tab

end  # class WebkitRemote::Browser

end  # namespace WebkitRemote
