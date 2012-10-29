# Top-level namespace.
module WebkitRemote
  # Launches a WebKit process locally, and sets up a debugger client for it.
  #
  # @param (see WebkitRemote::Process#initialize)
  # @return [WebkitRemote::Client] a debugging client connected to a local
  #     WebKit process; the client will automatically stop the process when
  #     closed
  def self.local(opts = {})
    process = WebkitRemote::Process.new opts
    browser = process.start
    browser.stop_process = true
    client = WebkitRemote::Client.new tab: browser.tabs.first,
                                      close_browser: true
    client
  end

  # Connects to a Webkit process, and sets up a debugger client for it.
  #
  # @param (see WebkitRemote::Browser#initialize)
  # @return [WebkitRemote::Client] a debugging client connected to the remote
  #     WebKit process; the connection will be automatically terminated when
  #     the debugging client is closed
  def self.remote(opts = {})
    browser = WebkitRemote::Browser.new opts
    # NOTE: connecting to the last tab to avoid internal tabs and whatnot
    client = WebkitRemote::Client.new tab: browser.tabs.last,
                                      close_browser: true
    client
  end
end  # namespace WebkitRemote
