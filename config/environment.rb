require_relative 'application'
require 'verification'
require 'exceptions'

ActiveSupport::Deprecation.silenced = true
Rails.Application.initialize!
