require 'base64'

module WebkitRemote

class Event

# Emitted when a chunk of data is received over the network.
class NetworkData < WebkitRemote::Event
  register 'Network.dataReceived'

  # @return [WebkitRemote::Client::NetworkResource] information about the
  #     resource fetched by this network operation
  attr_reader :resource

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @return [Number] number of bytes actually received
  attr_reader :bytes_received

  # @return [Number] number of data bytes received (after decompression)
  attr_reader :data_length

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    @data_length = raw_data['dataLength']
    @bytes_received = raw_data['encodedDataLength']
    @timestamp = raw_data['timestamp']

    @resource = client.network_resource raw_data['requestId']
    @resource.add_event self
  end
end  # class WebkitRemote::Event::NetworkData

# Emitted when a resource fails to load.
class NetworkFailure < WebkitRemote::Event
  register 'Network.loadingFailed'

  # @return [WebkitRemote::Client::NetworkResource] information about the
  #     resource fetched by this network operation
  attr_reader :resource

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @return [String] the error message
  attr_reader :error

  # @return [Boolean] true if the request was canceled
  #
  # For example, CORS violations cause requests to be canceled.
  attr_reader :canceled

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    @canceled = !!raw_data['canceled']
    @error = raw_data['errorText']
    @timestamp = raw_data['timestamp']

    @resource = client.network_resource raw_data['requestId']
    @resource.set_canceled @canceled
    @resource.set_error @error
    @resource.add_event self
  end
end  # class WebkitRemote::Event::NetworkFailure

# Emitted when a resource finishes loading from the network.
class NetworkLoad < WebkitRemote::Event
  register 'Network.loadingFinished'

  # @return [WebkitRemote::Client::NetworkResource] information about the
  #     resource fetched by this network operation
  attr_reader :resource

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    @timestamp = raw_data['timestamp']

    @resource = client.network_resource raw_data['requestId']
    @resource.add_event self
  end
end  # class WebkitRemote::Event::NetworkLoad

# Emitted when a resource is served from the local cache.
class NetworkCacheHit < WebkitRemote::Event
  register 'Network.requestServedFromCache'

  # @return [WebkitRemote::Client::NetworkResource] information about the
  #     resource fetched by this network operation
  attr_reader :resource

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super

    @resource = client.network_resource raw_data['requestId']
    @resource.add_event self
  end
end  # class WebkitRemote::Event::NetworkCacheHit

# Emitted when a resource is served from the local cache.
class NetworkMemoryCacheHit < WebkitRemote::Event
  register 'Network.requestServedFromMemoryCache'

  # @return [WebkitRemote::Client::NetworkResource] information about the
  #     resource fetched by this network operation
  attr_reader :resource

  # @return [WebkitRemote::Client::NetworkCacheEntry] cached information used
  #     to produce the resource
  attr_reader :cache_data

  # @return [String] the URL of the document that caused this network request
  attr_reader :document_url

  # @return [WebkitRemote::Client::NetworkRequestInitiator] cause for this
  #     network request
  attr_reader :initiator

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super

    if raw_data['resource']
      @cache_data = WebkitRemote::Client::NetworkCacheEntry.new(
          raw_data['resource'])
    end
    @document_url = raw_data['documentURL']
    if raw_data['initiator']
      @initiator = WebkitRemote::Client::NetworkRequestInitiator.new(
          raw_data['initiator'])
    end
    @loader_id = raw_data['loaderId']
    @timestamp = raw_data['timestamp']

    @resource = client.network_resource raw_data['requestId']
    @resource.set_document_url @document_url
    @resource.set_initiator @initiator
    if @cache_data
      @resource.set_response @cache_data.response
      @resource.set_type @cache_data.type
    end
    @resource.add_event self
  end
end  # class WebkitRemote::Event::NetworkMemoryCacheHit

# Emitted right before a network request.
class NetworkRequest < WebkitRemote::Event
  register 'Network.requestWillBeSent'

  # @return [WebkitRemote::Client::NetworkResource] information about the
  #     resource fetched by this network operation
  attr_reader :resource

  # @return [WebkitRemote::Client::NetworkRequest] information about this
  #     network request
  attr_reader :request

  # @return [String] the URL of the document that caused this network request
  attr_reader :document_url

  # @return [WebkitRemote::Client::NetworkRequestInitiator] cause for this
  #     network request
  attr_reader :initiator

  # @return [WebkitRemote::Client::NetworkResponse] the HTTP redirect that
  #     caused this request; can be nil
  attr_reader :redirect_response

  # @return [String] used to correlate events
  attr_reader :loader_id

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    @document_url = raw_data['documentURL']
    if raw_data['initiator']
      @initiator = WebkitRemote::Client::NetworkRequestInitiator.new(
          raw_data['initiator'])
    end
    @loader_id = raw_data['loaderId']
    if raw_data['request']
      @request = WebkitRemote::Client::NetworkRequest.new(
          raw_data['request'])
    end
    if raw_data['redirectResponse']
      @redirect_response = WebkitRemote::Client::NetworkResponse.new(
          raw_data['redirectResponse'])
    end
    if raw_data['stackTrace']
      @stack_trace = WebkitRemote::Client::ConsoleMessage.parse_stack_trace(
          raw_initiator['stackTrace'])
    else
      @stack_trace = nil
    end
    @timestamp = raw_data['timestamp']

    @resource = client.network_resource raw_data['requestId']
    @resource.set_document_url @document_url
    @resource.set_initiator @initiator
    @resource.set_request @request
    # TODO(pwnall): consider tracking redirects
    @resource.add_event self
  end

  # @private Use Event#can_receive instead of calling this directly.
  def self.can_reach?(client)
    client.network_events
  end
end  # class WebkitRemote::Event::NetworkRequest

# Emitted right after receiving a response to a network request.
class NetworkResponse < WebkitRemote::Event
  register 'Network.responseReceived'

  # @return [WebkitRemote::Client::NetworkResource] information about the
  #     resource fetched by this network operation
  attr_reader :resource

  # @return [WebkitRemote::Client::NetworkResponse] information about the HTTP
  #     response behind this event
  attr_reader :response

  # @return [Symbol] the type of resource returned by this response; documented
  #     values are :document, :font, :image, :other, :script, :stylesheet,
  #     :websocket and :xhr
  attr_reader :type

  # @return [Number] the event timestamp
  attr_reader :timestamp

  # @return [String] used to correlate events
  attr_reader :loader_id

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    @loader_id = raw_data['loaderId']
    if raw_data['response']
      @response = WebkitRemote::Client::NetworkResponse.new(
          raw_data['response'])
    end
    @type = (raw_data['type'] || 'other').downcase.to_sym
    @timestamp = raw_data['timestamp']

    @resource = client.network_resource raw_data['requestId']
    @resource.set_response @response
    @resource.set_type @type
    @resource.add_event self
  end

  # @private Use Event#can_receive instead of calling this directly.
  def self.can_reach?(client)
    client.network_events
  end
end  # class WebkitRemote::Event::NetworkResponse

end  # namespace WebkitRemote::Event


class Client

# Wraps information about the network operations for retrieving a resource.
class NetworkResource
  # @return [WebkitRemote::Client::NetworkRequest] network request (most likely
  #     HTTP) used to fetch this resource
  attr_reader :request

  # @return [WebkitRemote::Client::NetworkRequest] network response that
  #     contains this resource
  attr_reader :response

  # @return [Symbol] the type of this resource; documented values are
  #     :document, :font, :image, :other, :script, :stylesheet, :websocket and
  #     :xhr
  attr_reader :type

  # @return [String] the URL of the document that referenced this resource
  attr_reader :document_url

  # @return [WebkitRemote::Client::NetworkRequestInitiator] cause for this
  #     resource to be fetched from the network
  attr_reader :initiator

  # @return [Boolean] true if the request fetch was canceled
  attr_reader :canceled

  # @return [String] error message, if the resource fetching failed
  attr_reader :error

  # @return [WebkitRemote::Event] last event connected to this resource; can be
  #     used to determine the resource's status
  attr_reader :last_event

  # @return [WebkitRemote::Client] remote debugging client that reported this
  attr_reader :client

  # @return [String] request_id assigned by the remote WebKit debugger
  attr_reader :remote_id

  # Creates an empty network operation wrapper.
  #
  # @private Use WebkitRemote::Client::Network#network_op instead of calling
  #     this directly.
  # @param [String] remote_id the request_id used by the remote debugging
  #     server to identify this network operation
  # @param [WebkitRemote::Client]
  def initialize(remote_id, client)
    @remote_id = remote_id
    @client = client
    @request = nil
    @response = nil
    @type = nil
    @document_url = nil
    @initiator = nil
    @canceled = false
    @last_event = nil
    @body = false
  end

  # @return [String] the contents of the resource
  def body
    @body ||= body!
  end

  # Re-fetches the resource from the Webkit remote debugging server.
  #
  # @return [String] the contents of the resource
  def body!
    result = @client.rpc.call 'Network.getResponseBody', requestId: @remote_id
    if result['base64Encoded']
      @body = Base64.decode64 result['body']
    else
      @body = result['body']
    end
  end

  # @private Rely on the event processing code to set this property.
  def set_canceled(new_canceled)
    @canceled ||= new_canceled
  end

  # @private Rely on the event processing code to set this property.
  def set_document_url(new_document_url)
    return if new_document_url == nil
    @document_url = new_document_url
  end

  # @private Rely on the event processing code to set this property.
  def set_error(new_error)
    return if new_error == nil
    @error = new_error
  end

  # @private Rely on the event processing code to set this property.
  def set_initiator(new_initiator)
    return if new_initiator == nil
    @initiator = new_initiator
  end

  # @private Rely on the event processing code to set this property.
  def set_request(new_request)
    return if new_request == nil
    # TODO(pwnall): consider handling multiple requests
    @request = new_request
  end

  # @private Rely on the event processing code to set this property.
  def set_response(new_response)
    return if new_response == nil
    @response = new_response
  end

  # @private Rely on the event processing code to set this property.
  def set_type(new_type)
    return if new_type == nil
    @type = new_type
  end

  # @private Rely on the event processing code to set this property.
  def add_event(event)
    @last_event = event
    # TODO(pwnall): consider keeping track of all events
  end
end  # namespace WebkitRemote::Event

# Wraps information about HTTP requests.
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
  # @return [Symbol] reason behind the request; documented values are :parser,
  #     :script and :other
  attr_reader :type

  # @return [String] URL of the document that references the requested resource
  attr_reader :url

  # @return [Number] number of the line that references the requested resource
  attr_reader :line

  # @return [WebkitRemote::Console
  attr_reader :stack_trace

  # @private Use Event#for instead of calling this constructor directly
  def initialize(raw_initiator)
    if raw_initiator['lineNumber']
      @line = raw_initiator['lineNumber'].to_i
    else
      @line = nil
    end
    @stack_trace = WebkitRemote::Client::ConsoleMessage.parse_stack_trace(
        raw_initiator['stackTrace'])
    @type = (raw_initiator['type'] || 'other').to_sym
    @url = raw_initiator['url']
  end
end  # class WebkitRemote::Client::NetworkRequestInitiator


# Wraps information about a resource served out of the browser's cache.
class NetworkCacheEntry
  # @return [Symbol] the type of resource returned by this response; documented
  #     values are :document, :font, :image, :other, :script, :stylesheet,
  #     :websocket and :xhr
  attr_reader :type

  # @return [String] the URL of the response
  attr_reader :url

  # @return [WebkitRemote::Client::NetworkResponse] the cached response data
  attr_reader :response

  # @private Use Event#for instead of calling this constructor directly
  def initialize(raw_cached_resource)
    if raw_cached_resource['response']
      @response = WebkitRemote::Client::NetworkResponse.new(
          raw_cached_resource['response'])
    else
      @response = nil
    end
    @type = (raw_cached_resource['type'] || 'other').downcase.to_sym
    @url = raw_cached_resource['url']
  end
end  # namespace WebkitRemote::Client::NetworkCacheEntry

end  # namespace WebkitRemote::Client

end  # namepspace WebkitRemote
