module Requests
  module SessionHelpers
    def login_as(account)
      post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
    end
  end
end

RSpec.configure do |config|
  config.include Requests::SessionHelpers, type: :request
end
