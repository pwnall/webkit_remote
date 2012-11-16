require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'minitest/unit'
require 'minitest/spec'

require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'webkit_remote'

require 'debugger'
require 'pp'
require 'thread'
Thread.abort_on_exception = true

# Launch a dev server and wait until it starts.
pid = Process.spawn 'bundle exec puma --port 9969 --quiet --threads 1:1 ' +
    'test/fixtures/config.ru', :in => '/dev/null', :out => '/dev/null'
Process.detach pid
at_exit { Process.kill 'TERM', pid }
loop do
  begin
    response = Net::HTTP.get_response URI.parse('http://localhost:9969')
    break if response.kind_of?(Net::HTTPSuccess)
  rescue SystemCallError
    sleep 0.1
  end
end

class MiniTest::Unit::TestCase
  # URL for a file in the test/fixtures directory.
  def fixture_url(name, type = :html)
    "http://localhost:9969/#{type}/#{name}.#{type}"
  end
  # Path to a file in the test/fixtures directory.
  def fixture_path(name, type = :html)
    File.join File.dirname(__FILE__), "fixtures/#{type}/#{name}.#{type}"
  end
end

MiniTest::Unit.autorun
