require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::Page do
  before do
    @client = WebkitRemote.local port: 9669
  end
  after do
    @client.close
  end

  describe 'remote_eval' do
    it 'returns Ruby objects for primitives' do
      @client.remote_eval('11 + 32', group: 'no').must_equal 3
      @client.object_group('no').must_equal nil

      @client.remote_eval('!!1', group: 'no').,must_equal true
      @client.object_group('no').must_equal nil
      @client.remote_eval('!!0', group: 'no').,must_equal false
      @client.object_group('no').must_equal nil
    end

    it 'creates RemoteObject instances for JavaScript objects' do

    end
  end
end
