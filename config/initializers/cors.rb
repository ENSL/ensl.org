Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://gathers.ensl.org' # or your dev origin
    resource '*',
      headers: :any,
      methods: %i[get post put patch delete options],
      credentials: true
  end
end