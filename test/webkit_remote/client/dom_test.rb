require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Dom do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
    @client.navigate_to fixture_url(:dom)
    @client.wait_for type: WebkitRemote::Event::PageLoaded
  end
  after :all do
    @client.close
  end

  describe '#dom_root' do
    before :all do
      @root = @client.dom_root
    end

    it 'returns a WebkitRemote::Client::DomNode for a document' do
      @root.must_be_kind_of WebkitRemote::Client::DomNode
      @root.node_type.must_equal :document
      @root.name.must_equal '#document'
      @root.document_url.must_equal fixture_url(:dom)
    end
  end
end

describe WebkitRemote::Client::DomNode do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
    @client.navigate_to fixture_url(:dom)
    @client.wait_for type: WebkitRemote::Event::PageLoaded
    @root = @client.dom_root
  end
  after :all do
    @client.close
  end

  describe 'querySelector' do
    before :all do
      @p = @root.query_selector 'p#load-confirmation'
    end

    it 'returns a WebkitRemote::Client::DomNode' do
      @p.must_be_kind_of WebkitRemote::Client::DomNode
    end

    it 'returns a WebkitRemote::Client::DomNode with correct attributes' do
      skip 'On-demand node processing not implemented'
      @p.node_type.must_equal :element
      @p.name.must_equal 'P'
    end
  end

  describe 'querySelectorAll' do
    before :all do
      @p_array = @root.query_selector_all 'p'
    end

    it 'returns an array of WebkitRemote::Client::DomNodes' do
      @p_array.must_respond_to :[]
      @p_array.each { |p| p.must_be_kind_of WebkitRemote::Client::DomNode }
    end

    it 'returns the correct WebkitRemote::Client::DomNodes' do
      @p_array.map { |p| p.attributes['id'] }.
               must_equal ['load-confirmation', 'second-paragraph']
    end
  end

  describe 'attributes' do
    before :all do
      @p = @root.query_selector 'p#load-confirmation'
    end

    it 'produces a Hash of attributes' do
      @p.attributes.must_include 'data-purpose'
      @p.attributes['data-purpose'].must_equal 'attr-value-test'
    end
  end

  describe 'outer_html' do
    before :all do
      @p = @root.query_selector 'p#load-confirmation'
    end

    it 'returns the original HTML behind the element' do
      @p.outer_html.strip.must_equal <<DOM_END.strip
        <p id="load-confirmation" data-purpose="attr-value-test">
          DOM test loaded
        </p>
DOM_END
    end
  end
end
