# frozen_string_literal: true

# Policy here is to not to save version data unless its needed (eg. problems with new version)
# Version data is in Gemfile.lock, running bundle update will fix it.

source 'https://rubygems.org'
ruby '3.4.8'

# Rails core
gem 'msgpack', '>= 1.7.0'
gem 'rails', '~> 8.1.3'
gem 'rake'

# Dotenv
gem 'dotenv-rails'

# DB and caching
# Redis is pinned to 4 version
gem 'mysql2'
gem 'redis', '~> 4.8'
gem 'sidekiq'
gem 'sidekiq-cron'

# Reads the Parquet files exported by the ensl_analysis Python pipeline
# (embeds DuckDB; compiles a native extension on install, needs a C++
# toolchain -- already provided by build-essential in the Dockerfile).
gem 'duckdb'

# Web server.
# Faraday provides NET-HTTP functions
gem 'faraday'
gem 'net-ftp'
gem 'os'
gem 'puma'

# Rack-attack to stop spamming
gem 'rack-attack'

# CORS for external API's, not really used.
gem 'rack-cors'

# Logging. Add JSON logs with nice data.
# Objective: catch errors, easily parsable
gem 'lograge'

# Hotwire Turbo (Turbo Streams) for real-time updates
gem 'turbo-rails'

#
# Model plugins.

# Active_flag is used for soft-deletion of records with boolean column.
gem 'active_flag'
# Scrypt for secure password storage
gem 'scrypt'
# Unread for marking stuff read or unread
gem 'unread'
# Transform text to nice HTML
gem 'bbcoder'
gem 'commonmarker'
gem 'gemoji-parser'
# File attachments
gem 'carrierwave'
# Image manipulation, avatars
gem 'rmagick'
# Union for AR
gem 'active_record_union'
# Auditing/version tracking
gem 'paper_trail'

# External APIs.
# Steam condenders for querying Steam API and last to help with StemaIDs
gem 'google-api-client'
gem 'steam-condenser', github: 'koraktor/steam-condenser-ruby'
gem 'steam-id2'

# Auth
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-steam'
gem 'webauthn'

# gem 'ratyrate'
# gem "acts_as_rateable", :git => "git://github.com/anton-zaytsev/acts_as_rateable.git"

#
# View and view helper gems

# FIXME
# gem 'rails_csrf_protection'

# Pagination
gem 'will_paginate'

# Navigation
gem 'active_link_to'

# Form helpers
gem 'country_select'
# , require: 'country_select_without_sort_alphabetical'
# gem 'i18n_country_select'

# Captcha
gem 'recaptcha', require: 'recaptcha/rails'

# Provides URL parsing to links for customer content.
gem 'rails_autolink'

#
# Assets, JS and CSS

# Javascript
gem 'i18n-js'
gem 'jquery-rails'
gem 'local_time', '~> 3.0'
gem 'tinymce-rails'
gem 'twemoji-rails'

# CSS
gem 'dartsass-rails'
gem 'tailwindcss-rails'

# Provides il8n and respond functions
gem 'responders'

# Importmap for Rails. JS management without nodejs.
# Asset pipeline
gem 'importmap-rails', '~> 2.2'
gem 'propshaft'

group :production do
  # gem 'newrelic_rpm'
  gem 'puma_worker_killer'
end

group :development do
  # static code analyzers
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'rubocop-rails', require: false

  # annotate models
  # Does not support AR 8 yet
  # gem 'annotate'

  # Error message and console in browser
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console'

  # For converting erb to haml when needed
  gem 'erb2haml'
end

group :test do
  gem 'ostruct'

  gem 'rspec-benchmark'
  gem 'rspec-core'
  gem 'rspec-expectations'
  gem 'rspec-mocks'
  gem 'rspec-rails'
  gem 'rspec-support'

  # Model matchers for associations and validations
  gem 'shoulda-matchers'

  # Feature testing.
  # Capybara for integration testing
  # Playwright for headless browser testing
  gem 'apparition'
  gem 'capybara'
  gem 'capybara-playwright-driver'
  gem 'playwright-ruby-client'

  # HTML5 validation
  gem 'capybara-validate_html5'

  # Coverage
  gem 'simplecov', require: false

  # Time helpers for testing time-dependent features
  gem 'timecop'

  # For JS test
  gem 'mime-types'

  # Database cleaner
  gem 'database_cleaner'
  gem 'database_cleaner-active_record'
  # gem 'database_cleaner-redis'

  # Redis namespace for testing
  gem 'redis-namespace'

  # Block external HTTP in tests
  gem 'webmock'

  # Fix legacy issue
  gem 'rails-controller-testing'

  # Flaky tests
  # gem 'rspec-flaky'

  # For CircleCI
  # gem 'rspec_junit_formatter'

  # Old drivers not used atm.
  # gem 'selenium'
  # gem 'selenium-webdriver'
  # gem 'poltergeist'
  # gem 'phantomjs', require: 'phantomjs/poltergeist'

  # Fix FF issue
  # gem 'geckodriver-helper'
end

group :development, :test do
  # Debugging
  gem 'debug'

  # LSP support. For editors like VSCode
  gem 'ruby-lsp'
  gem 'ruby-lsp-rails'
  gem 'ruby-lsp-rspec', require: false

  # Better console with breakpoints
  gem 'pry-byebug'
  gem 'pry-rails'

  # Better output
  gem 'awesome_print'

  # Static analysis / code quality
  gem 'rails_best_practices'

  # Used both in development and test for generating realistic data
  gem 'factory_bot_rails'

  # gem 'spring'
  # gem 'ruby-debug-ide'
  # gem 'debase'

  # For n+1 query detection
  # gem 'bullet'
end
