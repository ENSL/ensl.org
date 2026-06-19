# frozen_string_literal: true

require 'rails_helper'

# Validates that every url() reference inside compiled CSS files (app/assets/builds/)
# points to a file that actually exists in Propshaft's asset load path.
#
# This catches the class of bug where an absolute /assets/... path is used in SCSS
# instead of a relative path, meaning Propshaft never fingerprints the reference and
# it will 404 in production.
#
# Run standalone:
#   bundle exec rspec spec/assets/css_references_spec.rb
#
# Skip if CSS hasn't been compiled yet:
#   SKIP_CSS_ASSET_CHECK=1 bundle exec rspec
RSpec.describe 'CSS compiled asset references', type: :request do
  let(:builds_dir) { Rails.root.join('app/assets/builds') }
  let(:load_path)  { Rails.application.assets.load_path }

  it 'all url() references in compiled CSS resolve to real assets' do
    skip 'SKIP_CSS_ASSET_CHECK is set' if ENV['SKIP_CSS_ASSET_CHECK'].present?

    expect(builds_dir).to satisfy('exist as a directory — run bin/rails dartsass:build first') do |d|
      Dir.exist?(d)
    end

    missing = []

    Pathname.glob(builds_dir.join('**/*.css')).sort.each do |css_file|
      # Logical base of this CSS file within the load path.
      # e.g. app/assets/builds/themes/default/theme.css → themes/default
      logical_base  = css_file.relative_path_from(builds_dir).dirname
      display_path  = css_file.relative_path_from(Rails.root)

      css_file.read.scan(/url\(["']?([^"')#\s]+)["']?\)/).flatten.each do |ref|
        # Skip external URLs, data URIs, and protocol-relative URLs
        next if ref.start_with?('http://', 'https://', 'data:', '//')

        # Absolute paths starting with / are never rewritten by Propshaft —
        # they are always wrong in compiled CSS (the bug we're guarding against).
        if ref.start_with?('/')
          missing << "#{display_path}: url(\"#{ref}\")  ← absolute path, Propshaft will not fingerprint this"
          next
        end

        # Resolve the relative reference against the CSS file's logical directory
        logical_path = Pathname.new(logical_base).join(ref).cleanpath.to_s

        unless load_path.find(logical_path)
          missing << "#{display_path}: url(\"#{ref}\") → #{logical_path} (not found in asset load path)"
        end
      end
    end

    expect(missing).to be_empty,
                       "#{missing.size} unresolvable asset reference(s) found in compiled CSS:\n\n" \
                       "#{missing.map { |m| "  #{m}" }.join("\n")}\n\n" \
                       'Fix: use a relative url() path in your SCSS so Propshaft can fingerprint it.'
  end
end
