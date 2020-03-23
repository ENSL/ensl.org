# frozen_string_literal: true

source 'http://rubygems.org'
ruby '2.5.7'

# Rails core
gem 'rails', '~> 6.0.2.1'
gem 'rake', '< 11.0'

# Dotenv
gem 'dotenv-rails'

# DB
# Fixme: using this bc puma startup problem
gem 'active_record_union'
gem 'dalli', '~> 2.7.0'
gem 'mysql2'

# Web server
gem 'faraday', '~> 0.9.0'
gem 'puma'

# Model plugins
# FIXME: using this b/c ruby 2.4 not supported
gem 'unread', '0.10.1'
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
gem 'steam-condenser', github: 'koraktor/steam-condenser-ruby'

# FIXME: Legacy feature shims
gem 'rails_autolink'
gem 'responders'

# Javascript
gem 'coffee-rails'
gem 'jquery-rails'
gem 'tinymce-rails'
gem 'i18n-js'

# Please install nodejs locally.
# gem 'therubyracer', '~> 0.12.1' if RUBY_PLATFORM == 'x86_64-linux'

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
  gem 'spring', '2.0.2'
  gem 'web-console', '3.7.0'
  gem 'rubocop'
end

group :test do
  #  gem 'spring'
  gem 'capybara'
  # gem 'codeclimate-test-reporter', require: nil
  # FIXME: Downgraded b/c of deprecations, fix static attributes
  gem 'factory_bot_rails', '4.10.0'
  gem 'phantomjs', require: 'phantomjs/poltergeist'
  gem 'poltergeist'
  gem 'selenium-webdriver'
  # Fix FF issue
  gem 'geckodriver-helper'
  # Fix legacy issue
  gem 'rails-controller-testing'
  gem 'simplecov', require: false
  gem 'test-unit'
  gem 'timecop'

  # FOr JS test
  gem 'mime-types'

  # Use dev versions because of rspec bug
  gem 'rspec-core', git: 'https://github.com/rspec/rspec-core'
  gem 'rspec-expectations', git: 'https://github.com/rspec/rspec-expectations'
  gem 'rspec-mocks', git: 'https://github.com/rspec/rspec-mocks'
  gem 'rspec-rails', git: 'https://github.com/rspec/rspec-rails'
  gem 'rspec-support', git: 'https://github.com/rspec/rspec-support'

  # Database cleaner
  gem 'database_cleaner-active_record'
  gem 'database_cleaner-redis'
end

group :development, :test do
  gem 'pry-rails'
  gem 'pry-byebug'
end
