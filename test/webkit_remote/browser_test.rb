require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Browser do
  before :each do
    @process = WebkitRemote::Process.new port: 9669
    @process.start
  end
  after :each do
    @process.stop
  end

  describe 'with process' do
    before :each do
      @browser = WebkitRemote::Browser.new process: @process
    end
    after :each do
      @browser.close
    end

    it 'sets the host and port correctly' do
      @browser.host.must_equal 'localhost'
      @browser.port.must_equal 9669
    end

    it 'enumerates the browser tabs correctly' do
      tabs = @browser.tabs
      tabs.length.must_equal 1
      tabs.first.must_be_kind_of WebkitRemote::Browser::Tab
      tabs.first.browser.must_equal @browser
      tabs.first.debug_url.must_match(/^ws:\/\/localhost:9669\//)
      tabs.first.url.must_equal 'about:blank'
    end

    it 'does not auto-stop the process by default' do
      @browser.stop_process?.must_equal false
      @browser.close
      @browser.closed?.must_equal true
      @process.running?.must_equal true
    end

    describe 'with process auto-stopping' do
      before do
        @browser.stop_process = true
      end

      it 'stops the process when closed' do
        @browser.stop_process?.must_equal true
        @browser.close
        @browser.closed?.must_equal true
        @process.running?.must_equal false
      end
    end
  end

  describe 'with host/port' do
    before :each do
      @browser = WebkitRemote::Browser.new host: 'localhost', port: 9669
    end
    after :each do
      @browser.close
    end

    it "does not support process auto-stopping" do
      @browser.stop_process.must_equal false
      lambda {
        @browser.stop_process = true
      }.must_raise ArgumentError
      @browser.stop_process.must_equal false
    end

    it 'enumerates the browser tabs correctly' do
      tabs = @browser.tabs
      tabs.length.must_equal 1
      tabs.first.must_be_kind_of WebkitRemote::Browser::Tab
      tabs.first.browser.must_equal @browser
      tabs.first.debug_url.must_match(/^ws:\/\/localhost:9669\//)
      tabs.first.url.must_equal 'about:blank'
    end
  end
end
