require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Console do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
  end
  after :all do
    @client.close
  end

  describe 'without console events enabled' do
    before :all do
      @client.console_events = false
      @client.navigate_to fixture_url(:console)
      @events = @client.wait_for type: WebkitRemote::Event::PageLoaded
    end

    it 'does not receive any console event' do
      @events.each do |event|
        @event.wont_be_kind_of WebkitRemote::Event::ConsoleMessage
      end
    end

    it 'cannot wait for console events' do
      lambda {
        @client.wait_for type: WebkitRemote::Event::ConsoleMessage
      }.must_raise ArgumentError
    end
  end

  describe 'with console events enabled' do
    before :all do
      @client.console_events = true
      @client.navigate_to fixture_url(:console)
      @events = @client.wait_for type: WebkitRemote::Event::PageLoaded
      @messages = @events.select do |event|
        event.kind_of? WebkitRemote::Event::ConsoleMessage
      end
    end

    after :all do
      @messages.each(&:release_params)
    end

    it 'receives console events' do
      @messages.wont_be :empty?
    end

    it 'parses text correctly' do
      @messages[0].text.must_equal 'hello ruby'
      @messages[0].params.must_equal ['hello ruby']
      @messages[0].level.must_equal :warning
      @messages[0].count.must_equal 1
      @messages[0].reason.must_equal :console_api
      @messages[0].type.must_equal :log
      @messages[0].source_url.must_equal fixture_url(:console)
      @messages[0].source_line.must_equal 7
    end


    it 'parses the stack trace correctly' do
      @messages[1].text.must_equal 'stack test'
      @messages[1].level.must_equal :log
      @messages[1].stack_trace.must_equal [
        { url: fixture_url(:console), line: 11, column: 19, function: 'f1' },
        { url: fixture_url(:console), line: 14, column: 11, function: 'f2' },
        { url: fixture_url(:console), line: 16, column: 9, function: '' },
        { url: fixture_url(:console), line: 17, column: 9, function: '' },
      ]
    end

    it 'parses parameters correctly' do
      @messages[2].text.must_match(/^params /)
      @messages[2].level.must_equal :error
      @messages[2].params[0, 3].must_equal ['params ', 42, true]
      @messages[2].params.length.must_equal 4

      @messages[2].params[3].must_be_kind_of WebkitRemote::Client::RemoteObject
      @messages[2].params[3].properties[:hello].value.must_equal 'ruby'
      @messages[2].params[3].group.name.must_equal nil
    end

    describe 'clear_console' do
      before :all do
        @client.clear_console
        @events = @client.wait_for type: WebkitRemote::Event::ConsoleCleared
      end

      it 'emits a ConsoleCleared event' do
        @events.last.must_be_kind_of WebkitRemote::Event::ConsoleCleared
      end
    end
  end
end
