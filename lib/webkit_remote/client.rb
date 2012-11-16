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
  #     that the tab belongs to will be closed when this RPC client's connection
  #     is closed
  def initialize(opts = {})
    unless tab = opts[:tab]
      raise ArgumentError, 'Target tab not specified'
    end
    @rpc = WebkitRemote::Rpc.new opts
    @debug_url = @rpc.debug_url
    @browser = tab.browser
    @close_browser = opts.fetch :close_browser, false
    @closed = false
    initialize_modules
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
      yield WebkitRemote::Event.for(rpc_event, self)
    end
    self
  end

  # Waits for the remote debugging server to send a specific event.
  #
  # @param (see WebkitRemote::Event#matches?)
  # @return [Array<WebkitRemote::Event>] all the events received, including the
  #     event that matches the class requirement
  def wait_for(conditions)
    unless WebkitRemote::Event.can_receive? self, conditions
      raise ArgumentError, "Cannot receive event with #{conditions.inspect}"
    end

    events = []
    each_event do |event|
      events << event
      break if event.matches?(conditions)
    end
    events
  end

  # Removes all the remote debugging data cached by this client.
  #
  # Some modules accumulate data throughout the debigging process. For example,
  # WebkitRemote::Client::Remote#remote_eval and
  # WebkitRemote::Events#ConsoleMessage build Ruby equivalents of the returned
  # JavaScript objects, and prevent Chrome from garbage-collecting the
  # returned JavaScript objects.
  #
  # Although modules have individual methods for releasing this data, such as
  # WebkitRemote::Client::RemoteGroup#release, keeping track of individual data
  # items is very inconvenient. Therefore, if you need to run a WebkitRemote
  # client for an extended period of time, you might find it easier to
  # periodically call this method.
  def clear_all
    clear_modules
  end

  # @return [WebkitRemote::Rpc] the WebSocket RPC client; useful for making raw
  #     RPC calls to unsupported methods
  attr_reader :rpc

  # @return [WebkitRemote::Browser] master session to the browser that owns the
  #     tab debugged by this client
  attr_reader :browser

  # Registers a module initializer.
  def self.initializer(name)
    before_name = :"initialize_modules_before_#{name}"
    alias_method before_name, :initialize_modules
    private before_name
    remove_method :initialize_modules
    eval <<END_METHOD
      def initialize_modules
        #{name}
        #{before_name.to_s}
      end
END_METHOD
    private :initialize_modules
  end

  # Registers a module clearer.
  def self.clearer(name)
    before_name = :"clear_modules_before_#{name}"
    alias_method before_name, :clear_modules
    private before_name
    remove_method :clear_modules
    eval <<END_METHOD
      def clear_modules
        #{name}
        #{before_name.to_s}
      end
END_METHOD
    private :clear_modules
  end

  # Called by the constructor. Aliased by the module initializers.
  #
  # @private Hook for module initializers to do their own setups.
  def initialize_modules
    # NOTE: this gets called after all the module initializers complete
  end
  private :initialize_modules

  # Called by clear_all.
  #
  # @private Hook for modules to run their own clearing code.
  def clear_modules
    # NOTE: this gets called after all the module cleaners complete
  end
  private :clear_modules

  # Debugging output.
  def inspect
    result = self.to_s
    result[-1, 0] =
        " server=#{@debug_url.inspect} closed=#{@closed.inspect}"
    result
  end
end  # class WebkitRemote::Client

end  # namespace WebkitRemote
