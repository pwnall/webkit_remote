require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Rpc do
  before :each do
    @process = WebkitRemote::Process.new port: 9669
    @process.start
    @browser = WebkitRemote::Browser.new process: @process, stop_process: true
    tab = @browser.tabs.first
    @rpc = WebkitRemote::Rpc.new tab: tab
  end
  after :each do
    @rpc.close if @rpc
    @browser.close if @browser
    @process.stop if @process
  end

  describe 'call' do
    before do
      @result = @rpc.call 'Runtime.evaluate', expression: '1 + 2',
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
      @rpc.call 'Page.enable'
      @rpc.call 'Page.navigate', url: fixture_url(:load)
      @events = []
      @rpc.each_event do |event|
        @events << event
        p event
        break if event[:name] == 'Page.loadEventFired'
      end
      p 'each_event exited'
    end

    it 'only yields events' do
      @events.each do |event|
        event.must_include :name
        event.must_include :data
      end
      p 'yield test done'
    end

    it 'contains a Page.loadEventFired event' do
      @events.map { |e| e[:name] }.must_include 'Page.loadEventFired'
      p 'event test done'
    end
  end
end

