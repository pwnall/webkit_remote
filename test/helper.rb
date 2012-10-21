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

require 'thread'
Thread.abort_on_exception = true

pid = Process.spawn 'bundle exec puma --port 9969 --quiet test/fixtures/config.ru',
                    :in => '/dev/null', :out => '/dev/null'
Process.detach pid
at_exit do
  Process.kill 'TERM', pid
end

class MiniTest::Unit::TestCase
  # URL for a file in the test/fixtures directory.
  def fixture_url(name)
    "http://localhost:9969/html/#{name}.html"
  end
end

MiniTest::Unit.autorun
