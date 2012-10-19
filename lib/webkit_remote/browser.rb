module WebkitRemote

# The master connection to a Webkit process.
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
  # @option opts [Boolean] auto_close if set to false, the
  #     WebkitRemote::Process passed to the constructor will not be
  #     automatically stopped
  def initialize(opts = {})
    if opts[:process]
      @process = opts[:process]
      @auto_close = opts.fetch :auto_close, false
      @host = process.host
      @port = process.port
    else
      @process = nil
      @auto_close = false
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
    @http.close
    @http = nil
    @process.stop if @auto_close
    @process = nil
    self
  end

  # Clean up when garbage collected.
  def finalize
    close unless @closed
  end
end  # class WebkitRemote::Browser

end  # namespace WebkitRemote
