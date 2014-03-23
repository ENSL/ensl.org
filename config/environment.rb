require File.expand_path('../application', __FILE__)
require 'dotenv'
require 'verification'
require 'exceptions'
require 'extra'

Dotenv.load
Ensl::Application.initialize!