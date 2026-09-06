# frozen_string_literal: true

def ensure_test_assets_built!
  return if ENV['SKIP_ASSET_BUILD'].present?

  theme_css = Rails.root.join('app/assets/builds/themes/default/theme.css')
  tailwind_css = Rails.root.join('app/assets/builds/tailwind.css')
  return if File.exist?(theme_css) && File.exist?(tailwind_css)

  puts 'Building assets for test environment...'
  success = system(
    { 'RAILS_ENV' => 'test' },
    'bin/rails', 'dartsass:build', 'tailwindcss:build'
  )
  abort('Asset build failed in test environment.') unless success
end

RSpec.configure do |config|
  config.before(:suite) do
    ensure_test_assets_built!
  end
end
