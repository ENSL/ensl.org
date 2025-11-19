# Load spec_helper
require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'

ActiveRecord::Migration.maintain_test_schema!

# load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  # Add your session helpers for controller specs
  config.include Controllers::SessionHelpers, type: :controller
  
  config.infer_spec_type_from_file_location!
end
