module WebkitRemote

class Client

# API for the Network domain.
module Network
  # Enables or disables the generation of events in the Network domain.
  #
  # @param [Boolean] new_network_events if true, the browser debugger will
  #     generate Network.* events
  def network_events=(new_network_events)
    new_network_events = !!new_network_events
    if new_network_events != network_events
      @rpc.call(new_network_events ? 'Network.enable' : 'Network.disable')
      @network_events = new_network_events
    end
    new_network_events
  end

  # Enables or disables the use of the network cache.
  #
  # @param [Boolean] new_disable_cache if true, the browser will not use its
  #     network cache, and will always generate HTTP requests
  def disable_cache=(new_disable_cache)
    new_disable_cache = !!new_disable_cache
    if new_disable_cache != disable_cache
      @rpc.call 'Network.setCacheDisabled', cacheDisabled: new_disable_cache
      @disable_cache = new_disable_cache
    end
    new_disable_cache
  end

  # Sets the User-Agent header that the browser will use to identify itself.
  #
  # @param [String] new_user_agent will be used instead of the browser's
  #     hard-coded User-Agent header
  def user_agent=(new_user_agent)
    if new_user_agent != user_agent
      @rpc.call 'Network.setUserAgentOverride', userAgent: new_user_agent
      @user_agent = new_user_agent
    end
    new_user_agent
  end

  # Sets extra headers to be sent with every HTTP request.
  #
  # @param [Hash<String, String>] new_extra_headers HTTP headers to be added to
  #     every HTTP request sent by the browser
  def http_headers=(new_http_headers)
    new_http_headers = Hash[new_http_headers.map { |k, v|
      [k.to_s, v.to_s]
    }].freeze
    if new_http_headers != http_headers
      @rpc.call 'Network.setExtraHTTPHeaders', headers: new_http_headers
      @http_headers = new_http_headers
    end
    new_http_headers
  end

  # Checks if the debugger can clear the browser's cookies.
  #
  # @return [Boolean] true if WebkitRemote::Client::Network#clear_cookies can
  #     be succesfully called
  def can_clear_cookies?
    response = @rpc.call 'Network.canClearBrowserCookies'
    !!response['result']
  end

  # Removes all the cookies in the debugged browser.
  #
  # @return [WebkitRemote::Client] self
  def clear_cookies
    @rpc.call 'Network.clearBrowserCookies'
    self
  end

  # Checks if the debugger can clear the browser's cache.
  #
  # @return [Boolean] true if WebkitRemote::Client::Network#clear_network_cache
  #     can be succesfully called
  def can_clear_network_cache?
    response = @rpc.call 'Network.canClearBrowserCache'
    !!response['result']
  end

  # Removes all the cached data in the debugged browser.
  #
  # @return [WebkitRemote::Client] self
  def clear_network_cache
    @rpc.call 'Network.clearBrowserCache'
    self
  end

  # @return [Boolean] true if the debugger generates Network.* events
  attr_reader :network_events

  # @return [Array<WebkitRemote::Client::NetworkResource>] the resources
  #     fetched during the debugging session
  #
  # This is only populated when Network events are received.
  attr_reader :network_resources

  # @return [Boolean] true if the browser's network cache is disabled, so every
  #     resource load generates an HTTP request
  attr_reader :disable_cache

  # @return [String] replaces the brower's built-in User-Agent string
  attr_reader :user_agent

  # @return [Hash<String, String>]
  attr_reader :http_headers

  # Looks up network resources by IDs assigned by the WebKit remote debugger.
  #
  # @private Use the #resource property of Network events instead of calling
  #     this directly.
  #
  # @param [String] remote_id the WebKit-assigned request_id
  # @return [WebkitRemote::Client::NetworkResource] the cached information
  #     about the resource with the given ID
  def network_resource(remote_id)
    if @network_resource_hash[remote_id]
      return @network_resource_hash[remote_id]
    end
    resource = WebkitRemote::Client::NetworkResource.new remote_id, self

    @network_resources << resource
    @network_resource_hash[remote_id] = resource
  end

  # Removes the cached network request information.
  #
  # @return [WebkitRemote::Client] self
  def clear_network
    @network_resource_hash.clear
    @network_resources.clear
    self
  end

  # @private Called by the Client constructor to set up Network data.
  def initialize_network
    @disable_cache = false
    @network_events = false
    @network_resources = []
    @network_resource_hash = {}
    @user_agent = nil
  end
end  # module WebkitRemote::Client::Network

initializer :initialize_network
include WebkitRemote::Client::Network

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
