# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/contests/_normal.html.erb
# Rendered from ContestsController#show for league contests (not ladder/bracket).
RSpec.describe 'contests/_normal', type: :view do
  before do
    view.define_singleton_method(:cuser) { nil }
  end

  it 'renders the contesters list for the contest, in ranked order' do
    contest = create(:contest, :league)
    top_team = create(:team, name: 'Top Team')
    bottom_team = create(:team, name: 'Bottom Team')
    create(:contester, contest: contest, team: bottom_team, score: 1, win: 1)
    create(:contester, contest: contest, team: top_team, score: 10, win: 5)

    render partial: 'contests/normal', locals: { contest: contest, friendly: nil }

    expect(rendered).to include('Top Team')
    expect(rendered).to include('Bottom Team')
    expect(rendered.index('Top Team')).to be < rendered.index('Bottom Team')
  end

  it 'excludes inactive contesters from the list' do
    contest = create(:contest, :league)
    active_team = create(:team, name: 'Active Team')
    inactive_team = create(:team, name: 'Inactive Team')
    create(:contester, contest: contest, team: active_team)
    create(:contester, contest: contest, team: inactive_team).update!(active: false)

    render partial: 'contests/normal', locals: { contest: contest, friendly: nil }

    expect(rendered).to include('Active Team')
    expect(rendered).not_to include('Inactive Team')
  end
end
