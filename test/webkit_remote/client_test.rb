require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client do
  before :each do
    @process = WebkitRemote::Process.new port: 9669, xvfb: true
    @process.start
    @browser = WebkitRemote::Browser.new process: @process, stop_process: true
    tab = @browser.tabs.first
    @client = WebkitRemote::Client.new tab: tab
  end
  after :each do
    @client.close if @client
    @browser.close if @browser
    @process.stop if @process
  end

  it 'sets close_browser to false, browser to the given Browser instance' do
    @client.close_browser?.must_equal false
    @client.browser.must_equal @browser
  end

  describe 'close with close_browser is true' do
    before do
      @client.close_browser = true
      @client.close
    end

    it 'closes the client debugging connection' do
      @client.closed?.must_equal true
    end

    it 'closes the browser master debugging session' do
      @browser.closed?.must_equal true
    end

    it 'still retuns a good inspect string' do
      @client.inspect.must_match(/<.*WebkitRemote::Client.*>/)
    end
  end

  describe 'each_event' do
    before do
      @client.rpc.call 'Page.enable'
      @client.rpc.call 'Page.navigate', url: fixture_url(:load)
      @events = []
      @client.each_event do |event|
        @events << event
        break if event.kind_of?(WebkitRemote::Event::PageLoaded)
      end
    end

    it 'only yields events' do
      @events.each do |event|
        event.must_be_kind_of WebkitRemote::Event
      end
    end

    it 'contains a PageLoaded instance' do
      @events.map(&:class).must_include WebkitRemote::Event::PageLoaded
    end
  end

  describe 'wait_for' do
    describe 'with page_events enabled' do
      before do
        @client.page_events = true
        @client.rpc.call 'Page.navigate', url: fixture_url(:load)
        @events = @client.wait_for type: WebkitRemote::Event::PageLoaded
      end

      it 'returns an array ending with a PageLoaded instance' do
        @events.wont_be :empty?
        @events.last.must_be_kind_of WebkitRemote::Event::PageLoaded
      end
    end

    describe 'with page_events disabled' do
      it 'raises ArgumentError' do
        lambda {
          @client.wait_for(type: WebkitRemote::Event::PageLoaded)
        }.must_raise ArgumentError
      end
    end
  end

  describe 'rpc' do
    it 'is is a non-closed WebkitRemote::Rpc instance' do
      @client.rpc.must_be_kind_of WebkitRemote::Rpc
      @client.rpc.closed?.must_equal false
    end

    describe 'after calling close' do
      before do
        @client_rpc = @client.rpc
        @client.close
      end

      it 'the Rpc instance is closed' do
        @client_rpc.closed?.must_equal true
      end
    end
  end

  describe 'clear_all' do
    it 'does not crash' do
      @client.clear_all
    end
  end

  describe 'inspect' do
    it 'includes the debugging URL and closed flag' do
      @client.inspect.must_match(
        /<WebkitRemote::Client:.*\s+server=".*"\s+closed=.+>/)
    end
  end
end

