source 'http://rubygems.org'

ruby '2.3.8'

gem 'rails', '~> 4.1.16'

# Dotenv
gem 'dotenv-rails'

# DB
# Fixme: using this bc puma startup problem
gem 'mysql2', '0.3.18'
gem 'dalli', '~> 2.7.0'
gem 'active_record_union'

# Web server
gem 'puma'
gem 'faraday', '~> 0.9.0'

# Model plugins
# FIXME: using this b/c ruby 2.4 not supported
gem 'unread', '0.10.1'

# View helper gems
gem 'nokogiri', '~> 1.9.0'
gem 'bbcoder', '~> 1.0.1'
gem 'sanitize', '~> 2.1.0'
gem 'carrierwave', '~> 0.10.0'
gem 'bluecloth', '~> 2.2.0'
gem 'rmagick'
gem 'will_paginate', '~> 3.0.5'
gem 'dynamic_form', '~> 1.1.4'
gem 'active_link_to', '~> 1.0.2'
gem 'country_select', require: 'country_select_without_sort_alphabetical'
gem 'i18n_country_select'
gem 'public_suffix', '~> 3.1.1'

# External APIs
gem 'google-api-client', '~> 0.10.3'
gem 'steam-condenser', github: 'koraktor/steam-condenser-ruby'

# Legacy feature shims
gem 'protected_attributes', '~> 1.1.3'
gem 'rails_autolink', '~> 1.1.5'

# Dependency version fix
gem 'signet', '0.11.0'

# Please install nodejs locally.
#gem 'therubyracer', '~> 0.12.1' if RUBY_PLATFORM == 'x86_64-linux'

# Move these to assets group
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails', '~> 2.0.2'
gem 'tinymce-rails', '~> 3.5.9'
gem 'sass-rails', '~> 5.0.3'
gem 'font-awesome-sass', '~> 4.1.0.0'
gem 'bourbon', '~> 3.1.8'
gem 'neat', '~> 1.6.0'
gem 'haml', '~> 4.0.5'
gem 'uglifier', '~> 2.5.0'
gem 'i18n-js'

group :production do
  gem 'newrelic_rpm', '~> 3.13.0.299'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'annotate'
  gem 'quiet_assets'
  gem 'web-console'
end

group :test do
#  gem 'spring'
  gem 'simplecov', '~> 0.7.1', require: false
  gem 'codeclimate-test-reporter', '~> 0.3.0', require: nil
  gem 'database_cleaner', '~> 1.2.0'
  gem 'rspec-rails', '~> 3.3.3'
  gem 'capybara', '~> 2.4.4'
  gem 'poltergeist', '~> 1.6.0'
  gem 'selenium-webdriver', '~> 2.47.1'
  gem 'factory_bot_rails'
  gem 'timecop', '~> 0.7.1'
  gem 'rspec'
  gem 'test-unit', '~> 3.1.3'
end

group :development, :test do
  gem 'pry-byebug', '~> 1.3.2'
end
