require File.expand_path('../application', __FILE__)
require 'verification'
require 'exceptions'
require 'extra'

ActiveSupport::Deprecation.silenced = true
Ensl::Application.initialize!
