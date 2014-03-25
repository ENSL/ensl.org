namespace :ci do
  task :deploy do
    require 'rubygems'
    require 'capistrano/all'
    require 'capistrano/setup'
    require 'capistrano/deploy'

    if ci_branch = ENV['TRAVIS_BRANCH']
      BRANCH_MAP = {
        # 'master' => 'production'
        'develop' => 'staging'
      }

      if BRANCH_MAP.include?(ci_branch)
        Capistrano::Application.invoke(BRANCH_MAP[ci_branch])
        Capistrano::Application.invoke("deploy")
      end
    else
      raise "Failed to deploy: Rake task called outside of CI environment"
    end
  end
end