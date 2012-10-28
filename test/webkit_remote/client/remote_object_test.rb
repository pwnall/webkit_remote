require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::RemoteObject do
  before :each do
    @client = WebkitRemote.local port: 9669
    @client.page_events = true
    @client.navigate_to fixture_url(:runtime)
    @client.wait_for type: WebkitRemote::Event::PageLoaded
  end
  after :each do
    @client.close
  end

  describe 'properties' do
    describe 'with simple JSON' do
      before :each do
        @object = @client.remote_eval 'window.t = ({answer: 42, test: true})'
      end

      it 'enumerates the properties correctly' do
        @object.properties[:answer].name.must_equal :answer
        @object.properties[:test].name.must_equal :test
        @object.properties[:other].must_equal nil
      end

      it 'gets the correct values' do
        @object.properties[:answer].value.must_equal 42
        @object.properties[:test].value.must_equal true
      end

      it 'sets owner correctly' do
        @object.properties[:answer].owner.must_equal @object
      end

      it 'does not have extra properties' do
        @object.properties.select { |name, property| property.enumerable? }.
                keys.sort.must_equal [:answer, :test]
      end

      it 'recognizes writable properties' do
        @object.properties[:answer].writable?.must_equal true
        @object.properties[:constructor].writable?.must_equal false
      end

      it 'recognizes configurable properties' do
        @object.properties[:answer].configurable?.must_equal true
        @object.properties[:constructor].configurable?.must_equal false
      end

      it 'recognizes enumerable properties' do
        @object.properties[:answer].enumerable?.must_equal true
        @object.properties[:constructor].enumerable?.must_equal false
      end

      describe 'after property update' do
        before do
          @object.properties[:DONE]
          @client.remote_eval 'window.t.test = "updated"'
        end
        it 'does not automatically refresh' do
          @object.properties[:test].value.must_equal true
        end
        it 'refreshes when properties! is called' do
          @object.properties![:test].value.must_equal 'updated'
        end
      end
    end

    describe 'with the XMHttpRequest built-in' do
      before :each do
        @object = @client.remote_eval 'XMLHttpRequest'
      end

      it 'recognizes configurable, non-writable, enumerable properties' do
        @object.properties[:DONE].configurable?.must_equal true
        @object.properties[:DONE].writable?.must_equal false
        @object.properties[:DONE].enumerable?.must_equal true
      end
    end
  end

  describe 'call' do
    before :each do
      @object = @client.remote_eval 'new TestClass("hello ruby")', group: 'g1'
    end
    after :each do
      group = @client.object_group 'g1'
      group.release_all if group
    end

    describe 'with a function that operates on primitives' do
      before :each do
        @result = @object.call 'TestClass.prototype.add3', ' answer:', 4, 2
      end
      it 'returns a native primitive type' do
        @result.must_equal 'hello ruby answer:42'
      end
    end

    describe 'with a function that returns a primitive' do
      before :each do
        @arg1 = @client.remote_eval 'new TestClass(" again")', group: 'g1'
        @arg2 = @client.remote_eval 'new TestClass(" ruby")', group: 'g2'
        @result = @object.call 'TestClass.prototype.add3', ' hello',
                               @arg1, @arg2
      end
      it 'returns a native primitive type' do
        @result.must_equal 'hello ruby hello again ruby'
      end
    end

    describe 'with objects' do
      before :each do
        @arg1 = @client.remote_eval '({hello: "rbx", goodbye: "java"})',
                                    group: 'g1'
        @arg2 = @client.remote_eval '({hello: "jruby", goodbye: "java2"})',
                                    group: 'g2'
        @result = @object.call 'TestClass.prototype.greetings', @arg1, @arg2
      end
      it 'passes the objects and returns an object correctly' do
        @result.must_be_kind_of WebkitRemote::Client::RemoteObject
        @result.js_class_name.must_equal 'TestClass'
        @result.call('TestClass.prototype.toString').
                must_equal 'hello ruby, rbx and jruby'
      end
      it 'adds the result to the target group' do
        @result.group.must_equal @object.group
      end
    end
  end
end
