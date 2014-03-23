source 'http://rubygems.org'

ruby '2.1.1'

gem 'rails', '~> 3.2.16'
gem 'mysql2', '~> 0.3.15'

# Deployment
gem 'foreman', '~> 0.63.0'
gem 'capistrano', '~> 3.1.0'
gem 'capistrano-rbenv', '~> 2.0.2'
gem 'capistrano-bundler', '~> 1.1.2'
gem 'capistrano-rails', '~> 1.1'

# Libraries
gem 'jquery-rails'
gem 'sass-rails'
gem 'coffee-rails'
gem 'gruff'
gem 'nokogiri'
gem 'carrierwave'
gem 'rbbcode'
gem 'tinymce-rails'
gem 'bluecloth', '~> 2.2.0'
gem 'bb-ruby'
gem 'therubyracer'
gem 'acts_as_indexed'
gem 'rmagick', require: false
gem 'will_paginate', git: 'https://github.com/p7r/will_paginate.git', branch: 'rails3'
gem 'newrelic_rpm', '~> 3.7.2.195'

group 'staging', 'production' do
  gem 'unicorn', '~> 4.8.2'
end

group 'development' do
  gem 'annotate', '~> 2.6.2'
end

group 'test' do
  gem 'simplecov', '~> 0.7.1', require: false
  gem 'rspec-rails', '~> 2.14.1'
  gem 'rspec-given', '~> 3.5.4'
  gem 'capybara', '~> 2.2.1'
  gem 'poltergeist', '~> 1.5.0'
  gem 'factory_girl_rails', '~> 4.4.1'
end

group 'development', 'test' do
  gem 'pry-debugger', '~> 0.2.2'
  gem 'dotenv-rails', '~> 0.10.0'
end
