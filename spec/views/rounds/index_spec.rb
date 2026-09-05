# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/rounds/index.html.erb
# (and the app/views/rounds/_rounds.html.erb partial it renders via
# `render :partial => "rounds", :object => @rounds`), now a minimal
# placeholder pending rework for the parquet-imported Round schema.
RSpec.describe 'rounds/index', type: :view do
  before do
    # rounds/_rounds passes merged params straight into `url_for`. The default
    # view-spec params object is an unpermitted ActionController::Parameters,
    # which blows up on that conversion - permit everything here so we can
    # exercise the actual rendering path.
    allow(view).to receive(:params).and_return(ActionController::Parameters.new({}).permit!)
  end

  it 'renders the archive heading and the rounds list with server/map/result data' do
    round = Round.create!(
      server_name: 'ENSL Server One',
      map_name: 'ns_eclipse',
      start_time: 2.days.ago,
      end_time: 2.days.ago + 20.minutes,
      result: Round::RESULT_MARINE_WIN
    )

    assign(:rounds, Round.where(id: round.id).paginate(page: 1, per_page: 30))

    render

    expect(rendered).to include('ENSL Round Archive')
    expect(rendered).to include('ENSL Server One')
    expect(rendered).to include('ns_eclipse')
    expect(rendered).to include('Marines')
  end

  it 'shows n/a for a round with no recorded start time' do
    round = Round.create!(server_name: 'ENSL Server One', map_name: 'ns_altair_legacy', start_time: nil)

    assign(:rounds, Round.where(id: round.id).paginate(page: 1, per_page: 30))

    render

    expect(rendered).to include('ns_altair_legacy')
    expect(rendered).to include('n/a')
  end
end

