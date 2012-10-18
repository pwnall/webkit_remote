require File.expand_path('../helper.rb', File.dirname(__FILE__))

require 'net/http'

describe WebkitRemote::Process do
  before :each do
    @process = WebkitRemote::Process.new port: 9669
  end
  after :each do
    @process.stop
  end

  describe '#running' do
    it 'returns false before #start is called' do
      @process.running?.must_equal false
    end
  end

  describe '#start' do
    before :each do
      @process.start
    end
    after :each do
      @process.stop
    end

    it 'makes running? return true' do
      @process.running?.must_equal true
    end

    it 'sets up a http server that responds to /json' do
      Net::HTTP.get(URI.parse('http://localhost:9669/json')).wont_be :empty?
    end

    describe '#stop' do
      before :each do
        @process.stop
      end

      it 'makes running? return false' do
        @process.running?.must_equal false
      end

      it 'kills the http server that responds to /json' do
        lambda {
          Net::HTTP.get(URI.parse('http://localhost:9669/json'))
        }.must_raise Errno::ECONNREFUSED
      end
    end
  end
end
