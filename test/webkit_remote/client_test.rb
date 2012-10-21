require File.expand_path('../helper.rb', File.dirname(__FILE__))

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
    before do
      @result = @client.rpc 'Runtime.evaluate', expression: '1 + 2',
                                                returnByValue: true
    end

    it 'produces the correct result' do
      @result.must_include 'result'
      @result['result'].must_include 'value'
      @result['result']['value'].must_equal 3
      @result['result'].must_include 'type'
      @result['result']['type'].must_equal 'number'
    end
  end

  describe 'each_event' do
    before do
      @client.rpc 'Page.enable'
      @client.rpc 'Page.navigate', url: fixture_url(:load)
      @events = []
      @client.each_event do |event|
        @events << event
        break if event[:name] == 'Page.loadEventFired'
      end
    end

    it 'only yields events' do
      @events.each do |event|
        event.must_include :name
        event.must_include :data
      end
    end

    it 'contains a Page.loadEventFired event' do
      @events.map { |e| e[:name] }.must_include 'Page.loadEventFired'
    end
  end
end

