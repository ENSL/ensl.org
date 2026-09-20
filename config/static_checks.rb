# frozen_string_literal: true

# Run using bin/static-checks

CI.run do
  step 'Setup', 'bin/setup --skip-server'
  step 'Static analysis: Ruby', 'bin/rubocop --except Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/ClassLength'
  step 'Static analysis: Rails design', 'bundle exec rails_best_practices --without-color .'
  step 'Static analysis: Brakeman', 'bundle exec brakeman --quiet --no-pager'
  step 'Static analysis: Gem audit', 'bin/bundler-audit'
  step 'Static analysis: Gem updates', 'bundle outdated'
  step 'Static analysis: Importmap audit', 'bin/importmap audit'
  step 'Static analysis: JavaScript vulnerabilities', 'yarn audit --level moderate'
  step 'Static analysis: CSS', 'yarn lint:css'
  step 'Static analysis: Zeitwerk compliance', 'bin/rails zeitwerk:check'
  step 'Static analysis: Leaked secrets', 'gitleaks detect --redact --no-banner'
end
