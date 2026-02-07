enable_simplecov = ENV['SIMPLECOV'] == '1' && !ARGV.any? { |a| a =~ /--only-failures|--next-failure/ }
if enable_simplecov
  require 'simplecov'

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
