# frozen_string_literal: true

source 'http://rubygems.org'

ruby '2.4.9'

# Rails core
gem 'rails', '~> 5.2.4.1'
gem 'rake', '< 11.0'
gem 'responders'

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
# gem "acts_as_rateable", :git => "git://github.com/anton-zaytsev/acts_as_rateable.git"

# View helper gems
gem 'active_link_to'
gem 'bbcoder'
gem 'bluecloth'
gem 'carrierwave'
gem 'country_select', require: 'country_select_without_sort_alphabetical'
gem 'dynamic_form'
gem 'i18n_country_select'
gem 'nokogiri'
gem 'public_suffix'
gem 'rmagick'
gem 'sanitize'
gem 'will_paginate', '~> 3.0.5'

# External APIs
gem 'google-api-client', '~> 0.10.3'
gem 'steam-condenser', github: 'koraktor/steam-condenser-ruby'

# FIXME: Legacy feature shims
# gem 'protected_attributes'
gem 'rails_autolink'

# Javascript
gem 'coffee-rails'
gem 'i18n-js'
gem 'jquery-rails'
gem 'tinymce-rails'

# Please install nodejs locally.
# gem 'therubyracer', '~> 0.12.1' if RUBY_PLATFORM == 'x86_64-linux'

gem 'bourbon','~> 3.1.8'
gem 'font-awesome-sass', '~> 4.1.0.0'
gem 'haml'
gem 'neat', '~> 1.6.0'
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
  gem 'codeclimate-test-reporter', require: nil
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'phantomjs', require: 'phantomjs/poltergeist'
  gem 'poltergeist'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'selenium-webdriver'
  gem 'simplecov', require: false
  gem 'test-unit'
  gem 'timecop'
end

group :development, :test do
  gem 'pry-byebug', '~> 1.3.2'
end
