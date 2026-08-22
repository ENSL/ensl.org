# frozen_string_literal: true

# Policy here is to not to save version data unless its needed (eg. problems with new version)
# Version data is in Gemfile.lock, running bundle update will fix it.

source 'https://rubygems.org'
ruby '3.4.8'

# Rails core
gem 'msgpack', '>= 1.7.0'
gem 'rails', '~> 8.1.3'
gem 'rake'

# Dotenv for loading env vars from .env files.
gem 'dotenv-rails'

# DB and caching. Sidekiq for background jobs.
# Redis is pinned to 4 version
gem 'mysql2'
gem 'redis', '~> 4.8'
gem 'sidekiq'
gem 'sidekiq-cron'

# Reads the Parquet files exported by the ensl_analysis Python pipeline
gem 'duckdb'

# Bayesian multiplayer rating system, used to rank teams from match results
gem 'openskill'

# Puma for Web server.
# Faraday provides NET-HTTP functions
gem 'faraday'
gem 'net-ftp'
gem 'os'
gem 'puma'

# Rack-attack to stop spamming
gem 'rack-attack'

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
# File attachments. RMagick for image manipulation, avatars
gem 'carrierwave'
gem 'rmagick'
# Union for AR. Certain models need this.
gem 'active_record_union'
# Auditing/version tracking
gem 'paper_trail'
# Semantic user and domain activity tracking
gem 'public_activity', '~> 3.0'

# External APIs. Google for calendar.
# Steam condensers for querying Steam API and last to help with SteamIDs
# CORS for external API's, not really used.
gem 'google-api-client'
gem 'rack-cors'
gem 'steam-condenser', github: 'koraktor/steam-condenser-ruby'
gem 'steam-id2'

# Auth. Omniauth for Steam login, WebAuthn for passkeys.
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-steam'
gem 'webauthn'

# gem 'ratyrate'
# gem "acts_as_rateable", :git => "git://github.com/anton-zaytsev/acts_as_rateable.git"

#
# View and view helper gems

# Pagination
gem 'will_paginate'

# Higlighted navigation links
gem 'active_link_to'

# Form helpers
gem 'country_select'
# , require: 'country_select_without_sort_alphabetical'
# gem 'i18n_country_select'

# Captcha
gem 'recaptcha', require: 'recaptcha/rails'

# Provides URL parsing to links for user content.
gem 'rails_autolink'

#
# Assets, JS and CSS

# Asset pipeline. Importmap for Rails. JS management without nodejs.
gem 'importmap-rails', '~> 2.2'
gem 'propshaft'

# Javascript.
gem 'i18n-js'
gem 'jquery-rails'
gem 'local_time', '~> 3.0'
gem 'tinymce-rails'
gem 'twemoji-rails'

# CSS. DartSass for SCSS, TailwindCSS for utility classes.
gem 'dartsass-rails'
gem 'tailwindcss-rails'

# Provides il8n and respond functions
gem 'responders'

group :production do
  # Puma worker killer to restart workers when memory usage is high
  gem 'puma_worker_killer'
end

group :development do
  # Error message and console in browser
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console'

  # For converting erb to haml when needed
  gem 'erb2haml'

  # annotate models
  # Does not support AR 8 yet
  # gem 'annotate'
end

group :test do
  # rspec for testing
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

  # JUnit XML output, consumed by GitHub Actions test-reporting steps
  gem 'rspec_junit_formatter'

  # Gem to build test data. Used in factories.
  gem 'ostruct'

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

  # Old drivers not used atm.
  # gem 'selenium'
  # gem 'selenium-webdriver'
  # gem 'poltergeist'
  # gem 'phantomjs', require: 'phantomjs/poltergeist'

  # Fix FF issue
  # gem 'geckodriver-helper'
end

group :development, :test do
  # Used both in development and test for generating realistic data
  gem 'factory_bot_rails'

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
  # In both envs for convenience.
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'rails_best_practices'
  gem 'rubocop'
  gem 'rubocop-rails', require: false

  # For n+1 query detection
  # gem 'bullet'

  # gem 'spring'
  # gem 'ruby-debug-ide'
  # gem 'debase'
end
