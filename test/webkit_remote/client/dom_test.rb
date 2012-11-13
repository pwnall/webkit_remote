require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Network do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
    @client.navigate_to fixture_url(:dom)
    @client.wait_for type: WebkitRemote::Event::PageLoaded
  end
  after :all do
    @client.close
  end


end
