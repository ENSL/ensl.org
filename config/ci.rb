# frozen_string_literal: true

# Run using bin/ci

CI.run do
  step 'Setup', 'bin/setup --skip-server'

  step 'Static analysis: Ruby', 'bin/rubocop'
  step 'Static analysis: Rails design', 'bundle exec rails_best_practices --without-color .'
  step 'Static analysis: Brakeman', 'bundle exec brakeman --quiet --no-pager'
  step 'Static analysis: Gem audit', 'bin/bundler-audit'
  step 'Static analysis: Importmap audit', 'bin/importmap audit'
  step 'Static analysis: CSS', 'yarn lint:css'

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
