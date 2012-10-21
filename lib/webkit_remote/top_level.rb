# Top-level namespace.
module WebkitRemote
  # Launches a WebKit process locally, and sets up a debugger client for it.
  #
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
end  # namespace WebkitRemote
