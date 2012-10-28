require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Event do
  before do
    @client = WebkitRemote.local port: 9669
  end
  after do
    @client.close
  end

  describe 'on a PageLoaded event' do
    before do
      @url = fixture_url(:load)
      @client.page_events = true
      @client.navigate_to @url
      events = []
      # NOTE: wait_for uses Event#matches, and we're testing that here
      @client.each_event do |event|
        events << event
        break if event.kind_of?(WebkitRemote::Event::PageLoaded)
      end
      @event = events.last
    end

    describe 'matches' do
      it 'handles single conditions' do
        @event.matches?(:class => WebkitRemote::Event::PageLoaded).
               must_equal true
        @event.matches?(type: WebkitRemote::Event).must_equal true
        @event.matches?(:class => WebkitRemote::Event::PageDomReady).
               must_equal false
        @event.matches?(name: 'Page.loadEventFired').must_equal true
        @event.matches?(name: 'loadEventFired').must_equal false
        @event.matches?(domain: 'Page').must_equal true
        @event.matches?(domain: 'Runtime').must_equal false
      end

      it 'handles multiple conditions' do
        @event.matches?(type: WebkitRemote::Event::PageLoaded,
                        domain: 'Page').must_equal true
        @event.matches?(type: WebkitRemote::Event::PageLoaded,
                        domain: 'Runtime').must_equal false
        @event.matches?(type: WebkitRemote::Event::PageDomReady,
                        domain: 'Page').must_equal false
      end
    end
  end

  describe 'can_receive?' do
    describe 'when page_events is false' do
      before do
        @client.page_events = false
      end
      it 'should be true for the base class' do
        WebkitRemote::Event.can_receive?(@client, type: WebkitRemote::Event).
                            must_equal true
      end
      it 'should be false for PageLoaded' do
        WebkitRemote::Event.can_receive?(@client,
            type: WebkitRemote::Event::PageLoaded).must_equal false
      end
      it 'should be false for Page.loadEventFired' do
        WebkitRemote::Event.can_receive?(@client, name: 'Page.loadEventFired').
                            must_equal false
      end
    end

    describe 'when page_events is true' do
      before do
        @client.page_events = true
      end
      it 'should be true for PageLoaded' do
        WebkitRemote::Event.can_receive?(@client,
            type: WebkitRemote::Event::PageLoaded).must_equal true
      end
      it 'should be true for Page.loadEventFired' do
        WebkitRemote::Event.can_receive?(@client, name: 'Page.loadEventFired').
                            must_equal true
      end
    end
  end
end

