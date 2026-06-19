# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.development?
      # Add here the dev hosts that need access
      origins 'http://localhost:8000', 'http://127.0.0.1:8000', '192.168.65.1'
    else
      origins 'https://gathers.ensl.org'
    end
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options],
             credentials: true
  end
end
