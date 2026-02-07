def ensure_test_assets_precompiled!
  return if ENV['SKIP_ASSET_PRECOMPILE'].present?

  assets_dir = Rails.root.join('public', 'assets')
  manifest = Dir[assets_dir.join('.sprockets-manifest*.json')].first ||
             Dir[assets_dir.join('manifest*.json')].first

  return if manifest && File.exist?(manifest)

  puts 'Precompiling assets for test environment...'
  success = system({ 'RAILS_ENV' => 'test' }, 'bin/rails', 'assets:precompile')
  abort('Assets precompile failed in test environment.') unless success
end

RSpec.configure do |config|
  config.before(:suite) do
    ensure_test_assets_precompiled!
  end
end
