module WebkitRemote

class Client

# API for the Page domain.
module Page
  # Loads a new URL into the tab under debugging.
  #
  # @param [String] url the URL to be loaded into the tab
  # @return [WebkitRemote::Client] self
  def navigate_to(url)
    @rpc.call 'Page.navigate', url: url
    self
  end

  # Reloads
  #
  # @param [Hash] opts quirky behavior bits
  # @option opts [Boolean] skip_cache if true, the cache is not used; this is
  #     what happens when the user presses Shift+refresh
  # @option opts [String] onload a JavaScript that will be injected in all the
  #     page's frames after reloading
  # @return [WebkitRemote::Client] self
  def refresh(opts = {})
    options = {}
    options[:ignoreCache] = true if opts[:skip_cache]
    options[:scriptToEvaluateOnLoad] = opts[:onload] if opts[:onload]
    @rpc.call 'Page.refresh', options
    self
  end

  # Enables or disables the generation of events in the Page domain.
  #
  # @param [Boolean] new_page_events if true, the browser debugger will
  #     generate Page.* events
  def page_events=(new_page_events)
    new_page_events = !!new_page_events
    if new_page_events != page_events
      @page_events = new_page_events
      @rpc.call(@page_events ? 'Page.enable' : 'Page.disable')
    end
    new_page_events
  end

  # @return [Boolean] true if the debugger generates Page.* events
  attr_reader :page_events

  # @private Called by the Client constructor to set up Page data structures.
  def initialize_page
    @page_events = nil
  end

end  # module WebkitRemote::Client::Page

initializer :initialize_page
include WebkitRemote::Client::Page

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
