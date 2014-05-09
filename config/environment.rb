require File.expand_path('../application', __FILE__)
require 'verification'
require 'exceptions'

ActiveSupport::Deprecation.silenced = true
Ensl::Application.initialize!
