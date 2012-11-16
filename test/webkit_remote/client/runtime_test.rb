require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Runtime do
  before :all do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
    @client.navigate_to fixture_url(:runtime)
    @client.wait_for type: WebkitRemote::Event::PageLoaded
  end
  after :all do
    @client.clear_all
    @client.close
  end

  describe 'remote_eval' do
    describe 'for a number' do
      before :each do
        @number = @client.remote_eval '11 + 31', group: 'no'
      end
      it 'returns a Ruby number' do
        @number.must_equal 42
      end
      it 'does not create an object group' do
        @client.object_group('no').must_equal nil
      end
    end

    describe 'for a boolean' do
      before :each do
        @true = @client.remote_eval '!!1', group: 'no'
        @false = @client.remote_eval '!!0', group: 'no'
      end
      it 'returns a Ruby boolean' do
        @true.must_equal true
        @false.must_equal false
      end
      it 'does not create an object group' do
        @client.object_group('no').must_equal nil
      end
    end

    describe 'for a string' do
      before :each do
        @string = @client.remote_eval '"hello Ruby"', group: 'no'
      end
      it 'returns a Ruby string' do
        @string.must_equal 'hello Ruby'
      end
      it 'does not create an object group' do
        @client.object_group('no').must_equal nil
      end
    end

    describe 'for null' do
      before :each do
        @null  = @client.remote_eval 'null', group: 'no'
      end
      it 'returns nil' do
        @string.must_equal nil
      end
      it 'does not create an object group' do
        @client.object_group('no').must_equal nil
      end
    end

    describe 'for undefined' do
      before :each do
        @undefined = @client.remote_eval '(function() {})()', group: 'no'
      end
      it 'returns an Undefined object' do
        @undefined.js_undefined?.must_equal true
        @undefined.to_s.must_equal ''
        @undefined.inspect.must_equal 'JavaScript undefined'
        @undefined.to_a.must_equal []
        @undefined.to_i.must_equal 0
        @undefined.to_f.must_equal 0.0
        @undefined.blank?.must_equal true
        @undefined.empty?.must_equal true
      end
      it 'does not create an object group' do
        @client.object_group('no').must_equal nil
      end
      it 'is idempotent' do
        @undefined.must_equal @client.remote_eval('(function(){})()')
      end
    end

    describe 'for an object created via new' do
      before :each do
        @object = @client.remote_eval 'new TestClass("hello Ruby")',
                                      group: 'yes'
      end
      after :each do
        group = @client.object_group('yes')
        group.release_all if group
      end
      it 'returns an JsObject instance' do
        @object.must_be_kind_of WebkitRemote::Client::JsObject
      end
      it 'sets the object properties correctly' do
        @object.js_class_name.must_equal 'TestClass'
        @object.description.must_equal 'TestClass'
      end
      it 'creates a non-released group' do
        @client.object_group('yes').wont_equal nil
        @client.object_group('yes').released?.must_equal false
      end
    end

    describe 'for a JSON object' do
      before :each do
        @object = @client.remote_eval '({hello: "ruby", answer: 42})',
                                      group: 'yes'
      end
      after :each do
        group = @client.object_group('yes')
        group.release_all if group
      end
      it 'returns an JsObject instance' do
        @object.must_be_kind_of WebkitRemote::Client::JsObject
      end
      it 'sets the object properties correctly' do
        @object.js_class_name.must_equal 'Object'
        @object.description.must_equal 'Object'
      end
      it 'creates a non-released group' do
        @client.object_group('yes').wont_equal nil
        @client.object_group('yes').released?.must_equal false
      end
    end

    describe 'for a function' do
      before :each do
        @function = @client.remote_eval '(function (a, b) { return a + b; })',
                                        group: 'yes'
      end
      after :each do
        group = @client.object_group('yes')
        group.release_all if group
      end

      it 'returns a JsObject instance' do
        @function.must_be_kind_of WebkitRemote::Client::JsObject
      end

      it 'sets the object properties correctly' do
        @function.js_class_name.must_equal 'Object'
        @function.js_type.must_equal :function
        @function.description.must_equal 'function (a, b) { return a + b; }'
      end

      it 'creates a non-released group' do
        @client.object_group('yes').wont_equal nil
        @client.object_group('yes').released?.must_equal false
      end
    end
  end


  describe 'clear_all' do
    describe 'with a named allocated object' do
      before :each do
        @object = @client.remote_eval '({hello: "ruby", answer: 42})',
                                      group: 'yes'
      end
      after :each do
        group = @client.object_group('yes')
        group.release_all if group
      end

      it 'releases the object and its group' do
        @client.clear_all
        @object.released?.must_equal true
        @client.object_group('yes').must_equal nil
      end
    end
  end
end
