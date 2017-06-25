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
      lambda {
        @client.wait_for type: WebkitRemote::Event::ConsoleCleared
      }.must_raise ArgumentError
    end
  end

  describe 'with console events enabled' do
    before :all do
      @client.console_events = true
      @client.navigate_to fixture_url(:console)
      @events = @client.wait_for type: WebkitRemote::Event::PageLoaded
      @message_events = @events.select do |event|
        event.kind_of? WebkitRemote::Event::ConsoleMessage
      end
      @messages = @client.console_messages
    end

    after :all do
      @client.clear_all
    end

    it 'receives ConsoleMessage events' do
      @message_events.wont_be :empty?
    end

    it 'collects messages into Client#console_messages' do
      @message_events[0].message.must_equal @messages[0]
      @message_events[1].message.must_equal @messages[1]
      @message_events[2].message.must_equal @messages[2]
      @message_events[3].message.must_equal @messages[3]
    end

    it 'parses text correctly' do
      @messages[0].text.must_equal 'hello ruby'
      @messages[0].level.must_equal :warning
      @messages[0].reason.must_equal :console_api
      @messages[0].source_url.must_equal fixture_url(:console)
      @messages[0].source_line.must_equal 7

      @messages[1].text.must_equal 'stack test'
      @messages[1].level.must_equal :log
      @messages[2].text.must_match(/^params /)
      @messages[2].level.must_equal :error
    end

=begin
    TODO(pwnall): Stacks are now available in Runtime.consoleAPICalled
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

    TODO(pwnall): Params are now available as args in Runtime.consoleAPICalled
    it 'parses parameters correctly' do
      @messages[2].text.must_match(/^params /)
      @messages[2].level.must_equal :error
      @messages[2].params[0, 3].must_equal ['params ', 42, true]
      @messages[2].params.length.must_equal 4

      @messages[2].params[3].must_be_kind_of WebkitRemote::Client::JsObject
      @messages[2].params[3].properties['hello'].value.must_equal 'ruby'
      @messages[2].params[3].group.name.must_be_nil
    end
=end

=begin
    describe 'clear_console' do
      before :all do
        @client.clear_console
        @events = @client.wait_for type: WebkitRemote::Event::ConsoleCleared
      end

      it 'emits a ConsoleCleared event' do
        @events.last.must_be_kind_of WebkitRemote::Event::ConsoleCleared
      end
    end

    describe 'clear_all' do
      before :all do
        @client.clear_all
        @events = @client.wait_for type: WebkitRemote::Event::ConsoleCleared
      end

      it 'calls clear_console, which emits a ConsoleCleared event' do
        @events.last.must_be_kind_of WebkitRemote::Event::ConsoleCleared
      end

      it 'releases the objects in ConsoleMessage instances' do
        @message_events[2].message.params[3].released?.must_equal true
      end
    end
=end
  end

=begin
  TODO(pwnall): These events are now available as Log.entryAdded
  describe 'with console and network events enabled' do
    before :all do
      @client.console_events = true
      @client.network_events = true
      @client.navigate_to fixture_url(:network)
      @events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage,
                                 level: :log
      @message_events = @events.select do |event|
        event.kind_of? WebkitRemote::Event::ConsoleMessage
      end
      @messages = @client.console_messages
    end

    after :all do
      @client.clear_all
    end

    it 'receives ConsoleMessage events' do
      @message_events.wont_be :empty?
    end

    it 'associates messages with network requests' do
      @messages[0].text.must_match(/not found/i)
      @messages[0].network_resource.wont_equal nil
      @messages[0].network_resource.document_url.
          must_equal fixture_url(:network)
      @messages[0].level.must_equal :error
      @messages[0].count.must_equal 1
      @messages[0].reason.must_equal :network
      @messages[0].type.must_equal :log
    end
  end
=end
end
