require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::RemoteObject do
  before :each do
    @client = WebkitRemote.local port: 9669
    @client.navigate_to fixture_url(:runtime)
  end
  after :each do
    @client.close
  end

  describe 'properties' do

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
        @result = @object.call 'TestClass.prototype.test_fn', "ruby", 4, 2
        # @result = @object.call 'function(a, b, c) { return a + b + c; };', "ruby", 4, 2
      end
      it 'returns a native primitive type' do
        @result.must_equal 'helloruby42'
      end
    end

    describe 'with a function that returns a primitive' do
      before :each do
        @arg1 = @client.remote_eval '({hello: "ruby", goodbye: "java"})',
                                    group: 'g1'
        @arg2 = @client.remote_eval '({hello: "ruby2", goodbye: "java2"})',
                                    group: 'g2'
        @result = @object.call 'test_fn', 'hello', @arg1, @arg2
      end
      it 'returns a native primitive type' do
        @result.must_equal 'hellorubyruby2'
      end
    end

    describe 'with objects' do
      before :each do
        @arg1 = @client.remote_eval '({hello: "ruby", goodbye: "java"})',
                                    group: 'g1'
        @arg2 = @client.remote_eval '({hello: "ruby2", goodbye: "java2"})',
                                    group: 'g2'
        @result = @object.call 'hellos', @arg1, @arg2
      end
      it 'passes the objects and returns an object correctly' do
        @result.must_be_kind_of WebkitRemote::Client::RemoteObject
        @result.js_class_name.must_equal 'TestClass'
        @result.call('toString').must_equal 'hello, ruby and ruby2'
      end
      it 'adds the result to the target group' do
        @result.group.must_equal @object.group
      end
    end
  end
end
