require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Network do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.console_events = true
    @client.disable_cache = true
  end
  after :all do
    @client.close
  end

  describe 'without network events enabled' do
    before :all do
      @client.network_events = false
      @client.navigate_to fixture_url(:network)
      @events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage,
                                 level: :log
    end

    it 'does not receive any network event' do
      @events.each do |event|
        @event.wont_be_kind_of WebkitRemote::Event::NetworkResponse
      end
    end

    it 'cannot wait for network events' do
      lambda {
        @client.wait_for type: WebkitRemote::Event::NetworkRequest
      }.must_raise ArgumentError
      lambda {
        @client.wait_for type: WebkitRemote::Event::NetworkResponse
      }.must_raise ArgumentError
    end
  end

  describe 'with network events enabled' do
    before :all do
      @client.disable_cache = true
      @client.network_events = true
      @client.navigate_to fixture_url(:network)
      @events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage,
                                 level: :log
      @requests = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkRequest
      end
      @responses = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkResponse
      end
      @loads = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkLoad
      end
      @chunks = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkData
      end
      @failures = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkFailure
      end
      @resources = @client.network_resources
    end

    it 'receives NetworkRequest events' do
      @requests.wont_be :empty?
    end

    it 'parses initial requests inside NetworkRequest events' do
      @requests[0].request.must_be_kind_of WebkitRemote::Client::NetworkRequest
      @requests[0].request.url.must_equal fixture_url(:network)
      @requests[0].request.method.must_equal :get
      @requests[0].request.headers.must_include 'User-Agent'
      @requests[0].request.headers['User-Agent'].must_match(/webkit/i)
      @requests[0].initiator.type.must_equal :other
      @requests[0].initiator.stack_trace.must_equal nil
    end

    it 'parses derived requests inside NetworkRequest events' do
      @requests[1].document_url.must_equal fixture_url(:network)
      @requests[1].request.must_be_kind_of WebkitRemote::Client::NetworkRequest
      @requests[1].request.url.must_equal fixture_url(:network_not_found, :js)
      @requests[1].initiator.type.must_equal :parser
      @requests[1].initiator.stack_trace.must_equal nil

      @requests[2].document_url.must_equal fixture_url(:network)
      @requests[2].request.must_be_kind_of WebkitRemote::Client::NetworkRequest
      @requests[2].request.url.must_equal fixture_url(:network, :js)
      @requests[2].initiator.type.must_equal :parser
      @requests[2].initiator.stack_trace.must_equal nil

      @requests[3].document_url.must_equal fixture_url(:network)
      @requests[3].request.must_be_kind_of WebkitRemote::Client::NetworkRequest
      @requests[3].request.url.must_equal fixture_url(:network, :png)
      @requests[3].initiator.type.must_equal :script
      @requests[3].initiator.stack_trace.must_equal [
        {column: 7, line: 10, function: "", url: fixture_url(:network, :js)},
        {column: 3, line: 11, function: "", url: fixture_url(:network, :js)},
      ]
    end

    it 'receives NetworkResponse events' do
      @responses.wont_be :empty?
    end

    it 'parses initial NetworkRequest and NetworkResponse events' do
      @responses[0].type.must_equal :document
      @requests[0].initiator.type.must_equal :other
      @requests[0].loader_id.wont_be :empty?
      @requests[0].loader_id.must_equal @responses[0].loader_id
      @requests[0].resource.remote_id.wont_be :empty?
      @requests[0].resource.must_equal @responses[0].resource
      @requests[0].timestamp.must_be :<, @responses[0].timestamp
    end

    it 'parses the initial response inside a NetworkResponse event' do
      @responses[0].type.must_equal :document
      @responses[0].response.
                   must_be_kind_of WebkitRemote::Client::NetworkResponse
      @responses[0].response.url.must_equal fixture_url(:network)
      @responses[0].response.status.must_equal 200
      @responses[0].response.status_text.must_equal 'OK'
      @responses[0].response.headers.must_include 'X-Unit-Test'
      @responses[0].response.headers['X-Unit-Test'].must_equal 'webkit-remote'
      @responses[0].response.mime_type.must_equal 'text/html'
      @responses[0].response.request_headers.must_include 'User-Agent'
      @responses[0].response.request_headers['User-Agent']
                   .must_match(/webkit/i)
      @responses[0].response.from_cache.must_equal false
      @responses[0].response.connection_reused.must_equal false
    end

    it 'parses a 404 response inside a NetworkResponse event' do
      @responses[1].type.must_equal :script
      @responses[1].response.
                   must_be_kind_of WebkitRemote::Client::NetworkResponse
      @responses[1].response.url.
                    must_equal fixture_url(:network_not_found, :js)
      @responses[1].response.status.must_equal 404
      @responses[1].response.status_text.must_match /not found/i
      @responses[1].response.headers.must_include 'X-Unit-Test'
      @responses[1].response.headers['X-Unit-Test'].must_equal 'webkit-remote'
      @responses[1].response.mime_type.must_equal 'text/plain'
      @responses[1].response.request_headers.must_include 'User-Agent'
      @responses[1].response.request_headers['User-Agent']
                   .must_match(/webkit/i)
      @responses[1].response.from_cache.must_equal false
    end

    it 'parses derived responses inside NetworkResponse events' do
      @responses[1].type.must_equal :script
      @responses[2].type.must_equal :script
      @responses[3].type.must_equal :xhr
    end

    it 'receives NetworkData events' do
      @chunks.wont_be :empty?
    end

    it 'parses NetworkData events' do
      @chunks[0].resource.must_equal @chunks[0].resource
      @chunks[0].data_length.
                 must_equal File.read(fixture_path(:network)).length
      @chunks[0].bytes_received.must_be :>, 0
    end

    it 'receives NetworkLoad events' do
      @loads.wont_be :empty?
    end

    it 'parses NetworkLoad events' do
      @loads[0].resource.must_equal @requests[0].resource
      @loads[1].resource.must_equal @requests[2].resource
    end

    it 'receives NetworkFailure events' do
      @failures.wont_be :empty?
    end

    it 'parses NetworkFailure events' do
      @failures[0].resource.must_equal @requests[1].resource
      @failures[0].error.wont_equal nil
      @failures[0].canceled.must_equal true
    end

    it 'collects request and response data in NetworkResources' do
      @resources[1].must_equal @requests[1].resource
      @resources[1].request.must_equal @requests[1].request
      @resources[1].response.must_equal @responses[1].response
      @resources[1].type.must_equal :script
      @resources[1].document_url.must_equal fixture_url(:network)
      @resources[1].initiator.must_equal @requests[1].initiator
      @resources[1].canceled.must_equal true
      @resources[1].error.must_equal @failures[0].error
      @resources[1].last_event.must_equal @failures[0]
      @resources[1].client.must_equal @client

      @resources[2].must_equal @requests[2].resource
      @resources[2].request.must_equal @requests[2].request
      @resources[2].response.must_equal @responses[2].response
      @resources[2].type.must_equal :script
      @resources[2].document_url.must_equal fixture_url(:network)
      @resources[2].initiator.must_equal @requests[2].initiator
      @resources[2].canceled.must_equal false
      @resources[2].error.must_equal nil
      @resources[2].last_event.must_equal @loads[1]
      @resources[2].client.must_equal @client

      @resources[-1].last_event.must_equal @chunks[-1]
    end

    it 'retrieves the body for a text NetworkResource' do
      @resources[0].body.must_equal File.read(fixture_path(:network))
    end

    it 'retrieves the body for a binary NetworkResource' do
      skip 'waiting for http://crbug.com/160397'
      @resources[2].body.must_equal File.binread(fixture_path(:network, :png))
    end
  end

  describe 'and a cached request' do
    before :all do
      @client.disable_cache = false
      @client.navigate_to fixture_url(:network)
      @client.wait_for type: WebkitRemote::Event::ConsoleMessage, level: :log
      @client.clear_all

      @client.network_events = true
      @client.navigate_to fixture_url(:network)
      @events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage,
                                 level: :log
      @requests = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkRequest
      end
      @responses = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkResponse
      end
      @loads = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkLoad
      end
      @chunks = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkData
      end
      @hits = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkCacheHit
      end
      @memory_hits = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkMemoryCacheHit
      end

      @resources = @client.network_resources
    end

    it 'receives NetworkCacheHit events' do
      @hits.wont_be :empty?
    end

    it 'parses NetworkCacheHits events' do
      @hits[0].resource.must_equal @requests[2].resource
    end

    it 'receives NetworkMemoryCacheHit events' do
      skip 'waiting for http://crbug.com/160404'
      @memory_hits.wont_be :empty?
    end
  end
end
