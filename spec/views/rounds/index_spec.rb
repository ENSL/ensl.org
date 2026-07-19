# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/rounds/index.html.erb
# (and the app/views/rounds/_rounds.html.erb partial it renders via
# `render :partial => "rounds", :object => @rounds`, flagged for simplification.)
# rubocop:disable Rails/SkipsModelValidations -- intentionally bypassing
# Round's required-association validations to build a minimal, circularly-
# referenced (round <-> commander) fixture for rendering only.
RSpec.describe 'rounds/index', type: :view do
  before do
    # rounds/_rounds passes merged params straight into `url_for`. The default
    # view-spec params object is an unpermitted ActionController::Parameters,
    # which blows up on that conversion - permit everything here so we can
    # exercise the actual rendering path.
    allow(view).to receive(:params).and_return(ActionController::Parameters.new({}).permit!)
  end

  def build_round(team1:, team2:, server:, commander_user:)
    match = create(:match, :scored)
    map = create(:map)

    round = Round.new(
      server: server,
      match: match,
      team1: team1,
      team2: team2,
      map: map,
      start: 2.days.ago,
      end: 2.days.ago + 20.minutes
    )
    round.save(validate: false)

    rounder = Rounder.create!(round: round, user: commander_user, ensl_team: team1)
    round.update_column(:commander_id, rounder.id)

    round
  end

  it 'renders the archive heading and the rounds list with server/team/map data' do
    server = create(:server, name: 'ENSL Server One')
    team1 = create(:team, name: 'Marine Team')
    team2 = create(:team, name: 'Alien Team')
    commander_user = create(:user, username: 'CommanderPlayer')

    round = build_round(team1: team1, team2: team2, server: server, commander_user: commander_user)

    assign(:rounds, Round.basic.where(id: round.id).paginate(page: 1, per_page: 30))

    render

    expect(rendered).to include('ENSL Round Archive')
    expect(rendered).to include('ENSL Server One')
    expect(rendered).to include('Marine Team')
    expect(rendered).to include('Alien Team')
    expect(rendered).to include('CommanderPlayer')
  end

  it 'falls back to the raw map name when no map record is linked' do
    server = create(:server)
    team1 = create(:team)
    team2 = create(:team)
    commander_user = create(:user)

    round = build_round(team1: team1, team2: team2, server: server, commander_user: commander_user)
    round.update_column(:map_id, nil)
    round.update_column(:map_name, 'ns_altair_legacy')

    assign(:rounds, Round.basic.where(id: round.id).paginate(page: 1, per_page: 30))

    render

    expect(rendered).to include('ns_altair_legacy')
  end
end
# rubocop:enable Rails/SkipsModelValidations
