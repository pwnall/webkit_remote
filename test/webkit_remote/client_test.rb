describe WebkitRemote::Client do
  before :each do
    @process = WebkitRemote::Process.new port: 9669
    @process.start
    @browser = WebkitRemote::Browser.new process: @process, stop_process: true
    tab = @browser.tabs.first
    @client = WebkitRemote::Client.new tab: tab, close_browser: true
  end
  after :each do
    @client.close if @client
    @browser.close if @browser
    @process.stop if @process
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
  end

  describe 'rpc' do
    it 'is is a non-closed WebkitRemote::Rpc instance' do
      @client.rpc.must_be_kind_of WebkitRemote::Rpc
      @client.rpc.closed?.must_equal false
    end

    describe 'after calling close' do
      before do
        @client.close
      end

      it 'is closed' do
        @client.rpc.closed?.must_equal true
      end
    end
  end
end

