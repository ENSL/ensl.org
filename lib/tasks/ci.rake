# frozen_string_literal: true

namespace :ci do
  task :deploy do
    require 'rubygems'
    require 'capistrano/all'
    require 'capistrano/setup'
    require 'capistrano/deploy'

    raise 'Failed to deploy: Rake task called outside of CI environment' unless (ci_branch = ENV['TRAVIS_BRANCH'])

    branch_map = {
      # 'master' => 'production'
      'develop' => 'staging'
    }.freeze

    if branch_map.include?(ci_branch)
      Capistrano::Application.invoke(branch_map[ci_branch])
      Capistrano::Application.invoke('deploy')
    end
  end
end
