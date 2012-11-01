require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Network do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
  end
  after :all do
    @client.close
  end

  describe 'without network events enabled' do
    before :all do
      @client.disable_cache = true
      @client.network_events = false
      @client.navigate_to fixture_url(:console)
      @events = @client.wait_for type: WebkitRemote::Event::PageLoaded
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
      @client.navigate_to fixture_url(:console)
      @events = @client.wait_for type: WebkitRemote::Event::PageLoaded
      @requests = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkRequest
      end
      @responses = @events.select do |event|
        event.kind_of? WebkitRemote::Event::NetworkResponse
      end
    end

    it 'receives NetworkRequest events' do
      @requests.wont_be :empty?
    end

    it 'parses the request inside NetworkRequest events correctly' do
      @requests[0].request.must_be_kind_of WebkitRemote::Client::NetworkRequest
      @requests[0].request.url.must_equal fixture_url(:console)
      @requests[0].request.method.must_equal :get
      @requests[0].request.headers.must_include 'User-Agent'
      @requests[0].request.headers['User-Agent'].must_match(/webkit/i)
    end

    it 'receives NetworkResponse events' do
      @responses.wont_be :empty?
    end

    it 'parses NetworkRequest and NetworkResponse events correctly' do
      @responses[0].type.must_equal :document
      @requests[0].loader_id.wont_be :empty?
      @requests[0].loader_id.must_equal @responses[0].loader_id
      @requests[0].request_id.wont_be :empty?
      @requests[0].request_id.must_equal @responses[0].request_id
      @requests[0].timestamp.must_be :<, @responses[0].timestamp
    end

    it 'parses the response inside NetworkResponse events correctly' do
      @responses[0].response.
                   must_be_kind_of WebkitRemote::Client::NetworkResponse
      @responses[0].response.url.must_equal fixture_url(:console)
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
  end
end
