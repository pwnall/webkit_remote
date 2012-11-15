require File.expand_path('helper.rb', File.dirname(__FILE__))

describe WebkitRemote do
  describe 'local' do
    before do
      @client = WebkitRemote.local port: 9669, xvfb: true
    end
    after do
      @client.close
    end

    it 'returns a working client' do
      @client.must_be_kind_of WebkitRemote::Client
      @client.closed?.must_equal false
    end

    describe 'after #close' do
      before do
        @client.close
      end

      it 'the client tears down everything' do
        @client.closed?.must_equal true
        @client.browser.closed?.must_equal true
        @client.browser.process.running?.must_equal false
      end
    end
  end

  describe 'remote' do
    before do
      @process = WebkitRemote::Process.new port: 9669, xvfb: true
      browser = @process.start
      browser.close
      @client = WebkitRemote.remote host: 'localhost', port: 9669
    end

    after do
      @client.close
      @process.stop
    end

    it 'returns a working client' do
      @client.must_be_kind_of WebkitRemote::Client
      @client.closed?.must_equal false
    end

    describe 'after #close' do
      before do
        @client.close
      end

      it 'the client tears the connection' do
        @client.closed?.must_equal true
        @client.browser.closed?.must_equal true
      end

      it 'the client does not impact the browser process' do
        @process.running?.must_equal true
      end
    end
  end
end
