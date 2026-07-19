# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/gathers/_picking.html.erb
#
# These specs intentionally write gather state directly via update_column(s)
# to avoid triggering Gather's heavy state-transition callbacks.
# rubocop:disable Rails/SkipsModelValidations
RSpec.describe 'gathers/_picking', type: :view do
  before do
    view.define_singleton_method(:cuser) { nil }
  end

  it 'renders the lobby, marines and aliens columns with the right players in each' do
    gather = create(:gather)
    gather.update_column(:status, Gather::STATE_PICKING)

    captain_user = create(:user, username: 'PickingCaptain')
    captain_gatherer = create(:gatherer, gather: gather, user: captain_user, team: 1, pick_order: 1)
    gather.update_columns(captain1_id: captain_gatherer.id, turn: 1)

    marine_user = create(:user, username: 'MarinePlayer')
    create(:gatherer, gather: gather, user: marine_user, team: 1, pick_order: 2)

    alien_user = create(:user, username: 'AlienPlayer')
    create(:gatherer, gather: gather, user: alien_user, team: 2, pick_order: 1)

    lobby_user = create(:user, username: 'LobbyPlayer')
    create(:gatherer, gather: gather, user: lobby_user, team: nil)

    assign(:gather, gather.reload)
    assign(:gatherer, nil)

    render

    expect(rendered).to include('Lobby')
    expect(rendered).to include('Marines')
    expect(rendered).to include('Aliens')
    expect(rendered).to include('LobbyPlayer')
    expect(rendered).to include('MarinePlayer')
    expect(rendered).to include('AlienPlayer')
    expect(rendered).to include('PickingCaptain')
  end

  it 'renders the lobby signup progress above the pick lists' do
    gather = create(:gather)
    gather.update_column(:status, Gather::STATE_PICKING)

    assign(:gather, gather.reload)
    assign(:gatherer, nil)

    render

    expect(rendered).to include('Players Picked')
  end
end
# rubocop:enable Rails/SkipsModelValidations
