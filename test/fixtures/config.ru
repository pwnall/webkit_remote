require 'bundler'
Bundler.setup :default, :development

use Rack::Static, urls: ['/html'], root: 'test/fixtures'
run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']] }
