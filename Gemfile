# frozen_string_literal: true

source 'http://rubygems.org'
ruby '2.6.5'

# Rails core
gem 'rails', '~> 6.0.2.2'
gem 'rake', '< 11.0'

# Dotenv
gem 'dotenv-rails'

# DB
# Fixme: using this bc puma startup problem
gem 'active_record_union'
gem 'dalli'
gem 'mysql2'

# Web server
gem 'faraday'
gem 'puma'
gem 'unicorn'

# Model plugins
gem 'unread'
# gem 'impressionist'
# gem 'ratyrate'
# gem "acts_as_rateable", :git => "git://github.com/anton-zaytsev/acts_as_rateable.git"

# View helper gems
gem 'active_link_to'
gem 'bbcoder'
gem 'bluecloth'
gem 'carrierwave'
gem 'nokogiri'
gem 'rmagick'
gem 'country_select', require: 'country_select_without_sort_alphabetical'
gem 'i18n_country_select'
gem 'dynamic_form'
gem 'public_suffix'
gem 'sanitize'
gem 'will_paginate'
gem 'time_difference'

# External APIs
gem 'google-api-client', '~> 0.10.3'
gem 'steam-condenser', g  ithub: 'koraktor/steam-condenser-ruby'

# FIXME: Legacy feature shims
gem 'rails_autolink'
gem 'responders'

# Javascript
gem 'coffee-rails'
gem 'jquery-rails'
gem 'tinymce-rails'
gem 'i18n-js'

gem 'bourbon','~> 3.1.8'

# Fix icons before updating
gem 'font-awesome-sass', '~> 4.1.0.0'
gem 'haml'

# Upgrading will cause issues
gem 'neat', '~> 1.6.0'

# This it outdated by sassc
gem 'sass-rails', '~> 5.0.3'
gem 'uglifier', '~> 2.5.0'

# Dependency version fix
gem 'signet', '0.11.0'

group :production do
  gem 'newrelic_rpm'
end

group :development do
  gem 'annotate'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console'
  gem 'rubocop'
end

group :test do
  # Use dev versions because of rspec bug
  gem 'rspec-core', git: 'https://github.com/rspec/rspec-core'
  gem 'rspec-expectations', git: 'https://github.com/rspec/rspec-expectations'
  gem 'rspec-mocks', git: 'https://github.com/rspec/rspec-mocks'
  gem 'rspec-rails', git: 'https://github.com/rspec/rspec-rails'
  gem 'rspec-support', git: 'https://github.com/rspec/rspec-support'

  # FIXME: Downgraded b/c of deprecations, fix static attributes
  gem 'factory_bot_rails', '4.10.0'

  # Feature testing
  gem 'capybara'
  gem 'phantomjs', require: 'phantomjs/poltergeist'
  gem 'poltergeist'
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
  # For n+1 uqeries
  # gem 'bullet'
end
