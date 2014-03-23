require File.expand_path('../application', __FILE__)
require 'dotenv'
require 'verification'
require 'exceptions'
require 'extra'

Dotenv.load
ActiveSupport::Deprecation.silenced = true if ['staging', 'production'].include?(ENV['RAILS_ENV'])

Ensl::Application.initialize!
