require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Input do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
    @client.navigate_to fixture_url(:input)
    @client.wait_for type: WebkitRemote::Event::PageLoaded
    @client.console_events = true
  end
  after :all do
    @client.close
  end

=begin
  describe '#mouse_event' do
    it 'generates a move correctly' do
      @client.mouse_event :move, 50, 50
      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'Move. x: 50 y: 50 button: 0 detail: 0 shift: false ctrl: false ' +
          'alt: false meta: false')
    end

    it 'generates a press correctly' do
      @client.mouse_event :down, 51, 52, button: :left, modifiers: [:shift]
      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'Down. x: 51 y: 52 button: 0 detail: 0 shift: true ctrl: false ' +
          'alt: false meta: false')
    end

    it 'generates a second press correctly' do
      @client.mouse_event :down, 51, 52, button: :right, clicks: 2,
                          modifiers: [:alt, :ctrl]
      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'Down. x: 51 y: 52 button: 2 detail: 2 shift: false ctrl: true ' +
          'alt: true meta: false')
    end

    it 'generates a release correctly' do
      @client.mouse_event :up, 51, 52, button: :middle, modifiers: [:command]
      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'Up. x: 51 y: 52 button: 1 detail: 0 shift: false ctrl: false ' +
          'alt: false meta: true')
    end
  end
=end

  describe '#key_event' do
    it 'generates a char correctly' do
      @client.key_event :char, text: 'a'

      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'KPress. keyCode: 97 charCode: 97 key:  text: undefined ' +
          'repeat: false shift: false ctrl: false alt: false meta: false')
    end

    it 'generates a down correctly' do
      @client.key_event :down, vkey: 0x41, key: 'A'

      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'KDown. keyCode: 65 charCode: 0 key: A text: undefined ' +
          'repeat: false shift: false ctrl: false alt: false meta: false')
    end

    it 'generates an up correctly' do
      @client.key_event :up, vkey: 0x41, key: 'A'

      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'KUp. keyCode: 65 charCode: 0 key: A text: undefined ' +
          'repeat: false shift: false ctrl: false alt: false meta: false')
    end

    it 'generates a raw_down correctly' do
      @client.key_event :raw_down, vkey: 0x41, key: 'A'

      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage

      events.last.message.text.must_equal(
          'KDown. keyCode: 65 charCode: 0 key: A text: undefined ' +
          'repeat: false shift: false ctrl: false alt: false meta: false')
    end
  end
end
