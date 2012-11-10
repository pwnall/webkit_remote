require 'bundler'
Bundler.setup :default, :development

require 'json'
require 'rack/contrib'

# Compression for Network domain testing.
use Rack::Deflater

# Custom header for Network domain testing.
use Rack::ResponseHeaders do |headers|
  headers['X-Unit-Test'] = 'webkit-remote'
end

# Cache headers for Network domain testing.
use Rack::StaticCache, urls: ['/html', '/js', '/png'], root: 'test/fixtures',
                       versioning: false, duration: 24 * 60 * 60
app = lambda do |env|
  [
    200,
    {'Content-Type' => 'application/json'},
    [JSON.dump(env)]
  ]
end
run app
