# frozen_string_literal: true

# Policy here is to not to save version data unless its needed (eg. problems with new version)
# Version data is in Gemfile.lock, running bundle update will fix it.

source 'https://rubygems.org'
ruby '3.2.5'

# Rails core
gem 'rails', '~> 8.1.1'
gem 'rake'

# Dotenv
gem 'dotenv-rails'

# DB
gem 'connection_pool' # Needed for MT
gem 'dalli'
gem 'mysql2'

# Web server
gem 'faraday'
gem 'os'
gem 'puma'
# gem 'unicorn'

# API
gem 'rack-cors'

# Model plugins
gem 'active_flag'
gem 'scrypt'
gem 'unread'
# gem 'impressionist
# gem 'ratyrate'
# gem "acts_as_rateable", :git => "git://github.com/anton-zaytsev/acts_as_rateable.git"

# External APIs
gem 'google-api-client'
gem 'steam-condenser', github: 'koraktor/steam-condenser-ruby'

# Auth
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-steam'
# FIXME
# gem 'rails_csrf_protection'

# View and model helper gems
gem 'active_link_to'
gem 'bbcoder'
gem 'bluecloth'
gem 'carrierwave'
gem 'country_select'
gem 'nokogiri'
gem 'public_suffix'
gem 'rmagick'
gem 'sanitize'
gem 'time_difference'
gem 'will_paginate'
# , require: 'country_select_without_sort_alphabetical'
# gem 'i18n_country_select'
gem 'dynamic_form'

# Views
gem 'haml'

# Javascript
gem 'coffee-rails'
gem 'i18n-js'
gem 'jquery-rails'
gem 'tinymce-rails'
gem 'uglifier'

# CSS
gem 'bourbon', '~> 3.1.8' # Upgrading will cause issues
gem 'font-awesome-sass', '~> 4.1.0.0' # Fix icons before updating
gem 'neat', '~> 1.6.0' # Upgrading will cause issues
gem 'sass-rails', '~> 5.0.3' # This it outdated by sassc

# FIXME: Legacy feature shims
gem 'active_record_union'
gem 'rails_autolink'
gem 'responders'

# FIXME: Dependency version fix
gem 'signet', '0.11.0'

# FIXME: Fix for warning: https://github.com/ruby/net-imap/issues/16
gem 'net-http'

# https://github.com/DatabaseCleaner/database_cleaner/issues/299
# gem 'mongoid-tree'
gem 'database_cleaner'

group :production do
  gem 'newrelic_rpm'
  gem 'puma_worker_killer'
end

group :development do
  # static code analyzers
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'rubocop-rails', require: false

  # annotate models
  gem 'annotate'

  # error message
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console'
end

group :test do
  # FIXME: Use dev versions because of rspec bug
  gem 'rspec-core'
  gem 'rspec-expectations'
  gem 'rspec-mocks'
  gem 'rspec-rails'
  gem 'rspec-support'

  # FIXME: Downgraded b/c of deprecations, fix static attributes
  gem 'factory_bot_rails', '4.10.0'

  # Feature testing
  gem 'capybara'
  #   gem 'poltergeist'
  gem 'apparition'
  # gem 'phantomjs', require: 'phantomjs/poltergeist'
  gem 'selenium'
  gem 'selenium-webdriver'

  # Fix FF issue
  # gem 'geckodriver-helper'

  # Fix legacy issue
  gem 'rails-controller-testing'

  # Coverage
  gem 'simplecov', require: false
  gem 'timecop'

  # HTML5 validation
  gem 'capybara-validate_html5'

  # Do I need this?
  gem 'test-unit'

  # For JS test
  gem 'mime-types'

  # Database cleaner
  gem 'database_cleaner-active_record'
  # gem 'database_cleaner-redis'
  gem 'redis-namespace'

  # For circle ci + CC
  #gem 'codeclimate-test-reporter', require: nil
  #gem 'rspec_junit_formatter'
end

group :development, :test do
  # Debugging
  gem 'rdbg'

  gem 'pry-byebug'
  gem 'pry-rails'

  gem 'awesome_print'
  gem 'rails_best_practices'

  # gem 'spring'
  # gem 'ruby-debug-ide'
  # gem 'debase'

  # For n+1 uqeries
  # gem 'bullet'

  gem 'erb2haml'
end
