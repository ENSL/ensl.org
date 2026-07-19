# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/gathers/_progress.html.erb
#
# These specs intentionally write gather state directly via update_column to
# avoid triggering Gather's heavy state-transition callbacks.
# rubocop:disable Rails/SkipsModelValidations
RSpec.describe 'gathers/_progress', type: :view do
  it 'shows sign-up progress for a running gather' do
    gather = create(:gather, :running)
    create_list(:gatherer, 5, gather: gather)

    assign(:gather, gather)
    assign(:gatherer, nil)

    render

    expect(rendered).to include('Signed Up')
    expect(rendered).to include('5/12')
  end

  it 'shows time remaining for a voting gather' do
    gather = create(:gather)
    create_list(:gatherer, 12, gather: gather)
    gather.update_column(:status, Gather::STATE_VOTING)

    assign(:gather, gather)
    assign(:gatherer, nil)

    render

    expect(rendered).to include('Voting Time Left')
    expect(rendered).to include('gather-progress-voting')
    expect(rendered).to include("data-total=\"#{gather.voting_timeout}\"")
  end

  it 'shows players-picked progress for a picking gather' do
    gather = create(:gather)
    create_list(:gatherer, 4, gather: gather, team: 1)
    create_list(:gatherer, 8, gather: gather, team: nil)
    gather.update_column(:status, Gather::STATE_PICKING)

    assign(:gather, gather)
    assign(:gatherer, nil)

    render

    expect(rendered).to include('Players Picked')
    expect(rendered).to include('8 left')
  end

  it 'shows "Complete" for a finished gather' do
    gather = create(:gather)
    gather.update_column(:status, Gather::STATE_FINISHED)

    assign(:gather, gather)
    assign(:gatherer, nil)

    render

    expect(rendered).to include('Teams Ready')
    expect(rendered).to include('Complete')
  end
end
# rubocop:enable Rails/SkipsModelValidations
