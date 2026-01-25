# spec/support/webmock.rb
# Prevent tests from making external HTTP requests by default.
begin
  require 'webmock/rspec'

  WebMock.disable_net_connect!(allow_localhost: true)
rescue LoadError
  warn 'webmock is not available; add gem "webmock" to :test group in Gemfile to block external requests.'
end
