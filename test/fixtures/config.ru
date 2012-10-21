require 'bundler'
Bundler.setup :default, :development

use Rack::Static, urls: ['/html'], root: 'test/fixtures'
app = lambda do |env|
  [
    200,
    {'Content-Type' => 'text/plain'},
    ['Fixture app catch-all page. Invalid test URL.']
  ]
end
run app
