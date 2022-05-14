# frozen_string_literal: true

# Policy here is to not to save version data unless its needed (eg. problems with new version)
# Version data is in Gemfile.lock, running bundle update will fix it.

source 'http://rubygems.org'
ruby '2.6.10'

# Rails core
gem 'rails', '~> 6.0.5'
gem 'rake'

# Dotenv
gem 'dotenv-rails'

# DB
gem 'mysql2'
gem 'dalli'
gem 'connection_pool' # Needed for MT

# Web server
gem 'faraday'
gem 'puma'
gem 'os'
# gem 'unicorn'

# Model plugins
gem 'unread'
gem 'scrypt'
gem 'active_flag'
# gem 'impressionist
# gem 'ratyrate'
# gem "acts_as_rateable", :git => "git://github.com/anton-zaytsev/acts_as_rateable.git"

# External APIs
gem 'google-api-client', '~> 0.10.3'
gem 'steam-condenser', github: 'koraktor/steam-condenser-ruby'

# Auth
gem 'omniauth'
gem 'omniauth-steam'
gem 'omniauth-rails_csrf_protection'
# FIXME
# gem 'rails_csrf_protection'

# View and model helper gems
gem 'time_difference'
gem 'public_suffix'
gem 'carrierwave'
gem 'bbcoder'
gem 'bluecloth'
gem 'nokogiri'
gem 'sanitize'
gem 'rmagick'
gem 'will_paginate'
gem 'active_link_to'
gem 'country_select', require: 'country_select_without_sort_alphabetical'
gem 'i18n_country_select'
gem 'dynamic_form'

# Views
gem 'haml'

# Javascript
gem 'coffee-rails'
gem 'jquery-rails'
gem 'tinymce-rails'
gem 'i18n-js'
gem 'uglifier'

# CSS
gem 'sass-rails', '~> 5.0.3' # This it outdated by sassc
gem 'bourbon','~> 3.1.8' # Upgrading will cause issues
gem 'neat', '~> 1.6.0' # Upgrading will cause issues
gem 'font-awesome-sass', '~> 4.1.0.0' # Fix icons before updating

# FIXME: Legacy feature shims
gem 'rails_autolink'
gem 'responders'
gem 'active_record_union'

# FIXME: Dependency version fix
gem 'signet', '0.11.0'

gem 'bundle-audit'

group :production do
  gem 'newrelic_rpm'
  gem 'puma_worker_killer'
end

group :development do
  # Check models
  gem 'rubocop'

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
  gem 'poltergeist'
  gem 'phantomjs', require: 'phantomjs/poltergeist'
  gem 'selenium-webdriver'

  # Fix FF issue
  gem 'geckodriver-helper'

  # Fix legacy issue
  gem 'rails-controller-testing'

  # Coverage
  gem 'simplecov', require: false
  gem 'timecop'

  # Do I need this?
  gem 'test-unit'

  # For JS test
  gem 'mime-types'

  # Database cleaner
  gem 'database_cleaner-active_record'
  gem 'database_cleaner-redis'

  # For circle ci + CC
  gem 'rspec_junit_formatter'
  gem 'codeclimate-test-reporter', require: nil
end

group :development, :test do
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'spring'
  gem "rails_best_practices"
  gem 'awesome_print'
  # For n+1 uqeries
  # gem 'bullet'
end
