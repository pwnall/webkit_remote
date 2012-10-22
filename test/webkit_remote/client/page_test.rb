require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Page do
  before do
    @client = WebkitRemote.local port: 9669
  end
  after do
    @client.close
  end

  describe 'navigate' do
    before do
      @url = fixture_url(:load)
      @client.page_events = true
      @client.navigate_to @url
      @events = []
      @client.each_event do |event|
        @events << event
        break if event.kind_of?(WebkitRemote::Event::PageLoaded)
      end
    end

    it 'changes the tab URL' do
      @client.browser.tabs.map(&:url).must_include @url
    end

    it 'fires a PageLoaded event' do
      @events.map(&:class).must_include WebkitRemote::Event::PageLoaded
    end
  end
end
