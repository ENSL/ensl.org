# frozen_string_literal: true

ci_enabled = ENV.key?('CI') && !%w[0 false].include?(ENV['CI'].to_s.downcase)
enable_simplecov = ENV['SIMPLECOV'] == '1' || ci_enabled

if enable_simplecov
  require 'simplecov'
  require 'simplecov_json_formatter'

  SimpleCov.coverage_dir('coverage')
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
                                                                    SimpleCov::Formatter::HTMLFormatter,
                                                                    SimpleCov::Formatter::JSONFormatter
                                                                  ])

  SimpleCov.start 'rails' do
    enable_coverage :branch
    add_filter %r{^/spec/}
    add_filter %r{^/config/}
    add_filter %r{^/db/}
    add_filter %r{^/vendor/}

    add_group 'Controllers', 'app/controllers'
    add_group 'Models',      'app/models'
    add_group 'Jobs',        'app/jobs'
    add_group 'Services',    'app/services'
  end
end
