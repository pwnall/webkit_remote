module WebkitRemote

class Event

# Emitted right before a network request.
class NetworkRequest < WebkitRemote::Event
  register 'Network.requestWillBeSent'

  # @return [WebkitRemote::Client::NetworkRequest] information about the HTTP
  #     request that prompted the response
  attr_reader :request

  # @return [WebkitRemote::Client::NetworkResponse] the HTTP redirect that
  #     caused this request; can be nil
  attr_reader :redirect_response

  # @return [String] the URL of the document that caused this network request
  attr_reader :document_url

  # @return [String] used to correlate events related to the same request
  attr_reader :request_id

  # @return [String] used to correlate events
  attr_reader :loader_id

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    @loader_id = raw_data['loaderId']
    @request_id = raw_data['requestId']
    if raw_data['request']
      @request = WebkitRemote::Client::NetworkRequest.new(
          raw_data['request'])
    end
    if raw_data['redirectResponse']
      @redirect_response = WebkitRemote::Client::NetworkResponse.new(
          raw_data['redirectResponse'])
    end
    @timestamp = raw_data['timestamp']

    # TODO(pwnall): implement missing attributes
  end

  # @private Use Event#can_receive instead of calling this directly.
  def self.can_reach?(client)
    client.network_events
  end
end  # class WebkitRemote::Event::NetworkRequest

# Emitted right after receiving a response to a network request.
class NetworkResponse < WebkitRemote::Event
  register 'Network.responseReceived'

  # @return [WebkitRemote::Client::NetworkResponse] information about the HTTP
  #     response behind this event
  attr_reader :response

  # @return [Symbol] the type of resource returned by this response; documented
  #     values are :document, :font, :image, :other, :script, :stylesheet,
  #     :websocket and :xhr
  attr_reader :type

  # @return [String] used to correlate events related to the same request
  attr_reader :request_id

  # @return [String] used to correlate events
  attr_reader :loader_id

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    @loader_id = raw_data['loaderId']
    @request_id = raw_data['requestId']
    if raw_data['response']
      @response = WebkitRemote::Client::NetworkResponse.new(
          raw_data['response'])
    end
    @type = (raw_data['type'] || 'other').downcase.to_sym
    @timestamp = raw_data['timestamp']
  end

  # @private Use Event#can_receive instead of calling this directly.
  def self.can_reach?(client)
    client.network_events
  end
end  # class WebkitRemote::Event::NetworkResponse

end  # namespace WebkitRemote::Event


class Client

# Wraps information about network requests.
class NetworkRequest
  # @return [String] the URL of the request
  attr_reader :url

  # @return [Symbol, nil] HTTP request method, e.g. :get
  attr_reader :method

  # @return [Hash<String, String>] the HTTP headers of the request
  attr_reader :headers

  # @return [String] the body of a POST request
  attr_reader :body

  # @private use Event#for instead of calling this constructor directly
  #
  # @param [Hash<String, Number>] the raw RPC data for a Response object
  #     in the Network domain
  def initialize(raw_response)
    @headers = raw_response['headers'] || {}
    @method = raw_response['method'] ? raw_response['method'].downcase.to_sym :
              nil
    @body = raw_response['postData']
    @url = raw_response['url']
  end
end  # class WebkitRemote::Client::NetworkRequest

# Wraps information about responses to network requests.
class NetworkResponse
  # @return [String] the URL of the response
  attr_reader :url

  # @return [Number] HTTP status code
  attr_reader :status

  # @return [String] HTTP status message
  attr_reader :status_text

  # @return [Hash<String, String>] HTTP response headers
  attr_reader :headers

  # @return [String] the browser-determined response MIME type
  attr_reader :mime_type

  # @return [Hash<String, String>] HTTP request headers
  attr_reader :request_headers

  # @return [Boolean] true if the request was served from cache
  attr_reader :from_cache

  # @return [Number] id of the network connection used by the browser to fetch
  #     this resource
  attr_reader :connection_id

  # @return [Boolean] true if the network connection used for this request was
  #     already open
  attr_reader :connection_reused

  # @private use Event#for instead of calling this constructor directly
  #
  # @param [Hash<String, Number>] the raw RPC data for a Response object
  #     in the Network domain
  def initialize(raw_response)
    @connection_id = raw_response['connectionId']
    @connection_reused = raw_response['connectionReused'] || false
    @from_cache = raw_response['fromDiskCache'] || false
    @headers = raw_response['headers'] || {}
    @mime_type = raw_response['mimeType']
    @request_headers = raw_response['requestHeaders'] || {}
    @status = raw_response['status']
    @status_text = raw_response['statusText']
    if raw_response['timing']
      @timing = WebkitRemote::Client::NetworkResourceTiming.new(
          raw_response['timing'])
    else
      @timing = nil
    end
    @url = raw_response['url']
  end
end  # class WebkitRemote::Client::NetworkResponse

# Wraps timing information for network events.
class NetworkResourceTiming
  # @param [Number] baseline time for the HTTP request used to fetch a resource
  attr_reader :time

  # @param [Number] milliseconds from {#time} until the start of the server DNS
  #     resolution
  attr_reader :dns_start_ms

  # @param [Number] milliseconds from {#time} until the server DNS resolution
  #     completed
  attr_reader :dns_end_ms

  # @param [Number] milliseconds from {#time} until the start of the proxy DNS
  #     resolution
  attr_reader :proxy_start_ms

  # @param [Number] milliseconds from {#time} until the proxy DNS resolution
  #     completed
  attr_reader :proxy_end_ms

  # @param [Number] milliseconds from {#time} until the TCP connection
  #     started being established
  attr_reader :connect_start_ms

  # @param [Number] milliseconds from {#time} until the TCP connection
  #     was established
  attr_reader :connect_end_ms

  # @param [Number] milliseconds from {#time} until the start of the SSL
  #     handshake
  attr_reader :ssl_start_ms

  # @param [Number] milliseconds from {#time} until the SSL handshake completed
  attr_reader :ssl_end_ms

  # @param [Number] milliseconds from {#time} until the HTTP request started
  #     being transmitted
  attr_reader :send_start_ms

  # @param [Number] milliseconds from {#time} until the HTTP request finished
  #     transmitting
  attr_reader :send_end_ms

  # @param [Number] milliseconds from {#time} until all the response HTTP
  #     headers were received
  attr_reader :receive_headers_end_ms

  # @private use Event#for instead of calling this constructor directly
  #
  # @param [Hash<String, Number>] the raw RPC data for a ResourceTiming object
  #     in the Network domain
  def initialize(raw_timing)
    @time = raw_timing['requestTime'].to_f

    @connect_start_ms = raw_timing['connectStart'].to_f
    @connect_end_ms = raw_timing['connectEnd'].to_f
    @dns_start_ms = raw_timing['dnsStart'].to_f
    @dns_end_ms = raw_timing['dnsEnd'].to_f
    @proxy_start_ms = raw_timing['proxyStart'].to_f
    @proxy_end_ms = raw_timing['proxyEnd'].to_f
    @receive_headers_end_ms = raw_timing['receiveHeadersEnd'].to_f
    @send_start_ms = raw_timing['sendStart'].to_f
    @send_end_ms = raw_timing['sendEnd'].to_f
    @ssl_start_ms = raw_timing['sslStart'].to_f
    @ssl_end_ms = raw_timing['sslEnd'].to_f
  end
end  # class WebkitRemote::Client::NetworkResourceTiming

# Wraps information about the reason behind a network request.
class NetworkRequestInitiator
  # @private use Event#for instead of calling this constructor directly
  def initialize(raw_initiator)

  end
end  # class WebkitRemote::Client::NetworkRequestInitiator

end  # namespace WebkitRemote::Client

end  # namepspace WebkitRemote
