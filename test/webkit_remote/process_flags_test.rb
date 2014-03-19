require File.expand_path('../helper.rb', File.dirname(__FILE__))

# This tests the command-line flags code by making sure that Chrome works in
# the intended fashion. By the nature of the test, it looks more like an
# integration test than the unit-level Process tests in process_test.rb.

describe WebkitRemote::Process do
  after :all do
    @client.close if @client
  end

  describe 'with allow_popups: true' do
    before :all do
      @client = WebkitRemote.local port: 9669, allow_popups: true
      @client.console_events = true
    end

    it 'runs through a page that uses window.open without a gesture' do
      @client.navigate_to fixture_url(:popup_user)
      events = @client.wait_for type: WebkitRemote::Event::ConsoleMessage
      events.last.message.text.must_equal 'Received popup message.'
    end
  end
end
