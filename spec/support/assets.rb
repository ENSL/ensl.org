# frozen_string_literal: true

def ensure_test_assets_precompiled!
  return if ENV['SKIP_ASSET_PRECOMPILE'].present?

  # Propshaft writes public/assets/.manifest.json after assets:precompile
  manifest = Rails.root.join('public/assets/.manifest.json')
  return if File.exist?(manifest)

  puts 'Precompiling assets for test environment...'
  # dartsass:build and tailwindcss:build must run before assets:precompile
  # because Propshaft does not compile — it only fingerprints existing files.
  success = system(
    { 'RAILS_ENV' => 'test' },
    'bin/rails', 'dartsass:build', 'tailwindcss:build', 'assets:precompile'
  )
  abort('Assets precompile failed in test environment.') unless success
end

RSpec.configure do |config|
  config.before(:suite) do
    ensure_test_assets_precompiled!
  end
end
