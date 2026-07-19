# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/gatherers/_list.html.erb
#
# These specs intentionally write gather state directly via update_column(s)
# to avoid triggering Gather/Gatherer's heavy state-transition callbacks
# (check_status, check_captains, change_turn), which have unrelated
# preconditions and side effects that would only get in the way here.
# rubocop:disable Rails/SkipsModelValidations
RSpec.describe 'gatherers/_list', type: :view do
  def picking_gather
    gather = create(:gather)
    gather.update_column(:status, Gather::STATE_PICKING)
    gather
  end

  it "renders pick controls when it's the viewing captain's turn to pick" do
    gather = picking_gather
    captain_user = create(:user, username: 'CaptainOne')
    captain_gatherer = create(:gatherer, gather: gather, user: captain_user, team: nil)
    gather.update_columns(captain1_id: captain_gatherer.id, turn: 1)

    candidate_user = create(:user, username: 'PickableCandidate')
    create(:gatherer, gather: gather, user: candidate_user, team: nil)

    # gather_current_user's default arg (gatherer_from_context) still reads
    # @gatherer directly off the view/controller rather than a local.
    assign(:gatherer, captain_gatherer)

    render partial: 'gatherers/list', locals: { team: nil, gather: gather.reload, gatherer: captain_gatherer }

    expect(rendered).to include('PickableCandidate')
    expect(rendered).to include('type="radio"')
    expect(rendered).to include('value="Pick"')
  end

  it 'renders a plain roster (no pick controls) for a team the viewer cannot pick for' do
    gather = picking_gather
    captain_user = create(:user, username: 'CaptainTwo')
    captain_gatherer = create(:gatherer, gather: gather, user: captain_user, team: 1, pick_order: 1)
    gather.update_columns(captain1_id: captain_gatherer.id, turn: 2)

    teammate_user = create(:user, username: 'TeamRosterPlayer')
    create(:gatherer, gather: gather, user: teammate_user, team: 1, pick_order: 2)

    viewer_user = create(:user, username: 'SpectatorViewer')
    viewer_gatherer = create(:gatherer, gather: gather, user: viewer_user, team: nil)

    assign(:gatherer, viewer_gatherer)

    render partial: 'gatherers/list', locals: { team: 1, gather: gather.reload, gatherer: viewer_gatherer }

    expect(rendered).to include('TeamRosterPlayer')
    expect(rendered).not_to include('type="radio"')
    expect(rendered).not_to include('value="Pick"')
  end

  it "shows the captain's star badge on the team roster" do
    gather = picking_gather
    captain_user = create(:user, username: 'StarCaptain')
    captain_gatherer = create(:gatherer, gather: gather, user: captain_user, team: 1, pick_order: 1)
    gather.update_columns(captain1_id: captain_gatherer.id, turn: 1)

    render partial: 'gatherers/list', locals: { team: 1, gather: gather.reload, gatherer: nil }

    expect(rendered).to include('StarCaptain')
    expect(rendered).to include('captain')
    expect(rendered).to include('fa-star')
  end
end
# rubocop:enable Rails/SkipsModelValidations
