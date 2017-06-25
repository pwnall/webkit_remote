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
    describe 'with a selector that matches' do
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

    describe 'with a selector that does not match' do
      it 'returns nil' do
        node = @root.query_selector '#this-id-should-not-exist'
        node.must_be_nil
      end
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

  describe 'remove' do
    before :all do
      @p = @root.query_selector 'p#load-confirmation'
      @p.remove
    end

    it 'removes the node from the DOM tree' do
      @root.query_selector_all('p').length.must_equal 1
    end
  end

  describe 'remove_attribute' do
    describe 'without cached data' do
      before :all do
        @p = @root.query_selector 'p#load-confirmation'
        @p.remove_attribute 'data-purpose'
      end

      it 'strips the attribute from the element' do
        @p.attributes!.wont_include 'data-purpose'
      end
    end

    describe 'with cached data' do
      before :all do
        @p = @root.query_selector 'p#load-confirmation'
        @p.attributes
        @p.remove_attribute 'data-purpose'
      end

      it 'strips the attribute from the element' do
        @p.attributes.wont_include 'data-purpose'
      end
    end
  end

  describe 'js_object' do
    before :all do
      @p = @root.query_selector 'p#load-confirmation'
      @js_object = @p.js_object
    end

    it 'returns the corresponding WebkitRemote::Client::JsObject' do
      @js_object.must_be_kind_of WebkitRemote::Client::JsObject
      @js_object.properties['tagName'].value.must_equal 'P'
      @js_object.properties['baseURI'].value.must_equal fixture_url(:dom)
    end

    it 'dom_node returns the DomNode back' do
      @js_object.dom_node.must_equal @p
    end
  end
end
