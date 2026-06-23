# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'matches/_list', type: :view do
  def build_match(contest:, home_team:, away_team:, score1:, score2:, points1: nil, points2: nil)
    home = create(:contester, contest: contest, team: home_team)
    away = create(:contester, contest: contest, team: away_team)

    create(
      :match,
      contest: contest,
      contester1: home,
      contester2: away,
      score1: score1,
      score2: score2,
      points1: points1,
      points2: points2,
      match_time: Time.current
    )
  end

  it 'shows opponent relative to friendly team and keeps score in home order' do
    contest = create(:contest, contest_type: Contest::TYPE_LEAGUE)
    home_team = create(:team, name: 'Home Team', tag: 'HOME')
    away_team = create(:team, name: 'Away Team', tag: 'AWAY')
    match = build_match(contest: contest, home_team: home_team, away_team: away_team, score1: 3, score2: 1)

    render partial: 'matches/list', locals: { matches: [match], friendly: away_team, contest: false }

    doc = Nokogiri::HTML.fragment(rendered)
    first_row = doc.css('table#matches tr')[1]

    expect(first_row).not_to be_nil
    expect(first_row.css('td')[0].text).to include('Home Team')
    expect(first_row.at_css('td.score').text).to include('3 - 1')
  end

  it 'colors score by home result and keeps home score first even when friendly is away' do
    contest = create(:contest, contest_type: Contest::TYPE_LEAGUE)
    home_team = create(:team, name: 'Color Home', tag: 'CH')
    away_team = create(:team, name: 'Color Away', tag: 'CA')
    match = build_match(contest: contest, home_team: home_team, away_team: away_team, score1: 1, score2: 3)

    render partial: 'matches/list', locals: { matches: [match], friendly: away_team, contest: false }

    doc = Nokogiri::HTML.fragment(rendered)
    score_link = doc.at_css('td.score a')

    expect(score_link).not_to be_nil
    expect(score_link.text).to include('1 - 3')
    expect(score_link['class']).to include('red')
    expect(score_link['class']).not_to include('green')
  end

  it 'renders points column before score in ladder lists' do
    contest = create(:contest, contest_type: Contest::TYPE_LADDER)
    home_team = create(:team, name: 'Ladder Home', tag: 'LH')
    away_team = create(:team, name: 'Ladder Away', tag: 'LA')
    match = build_match(
      contest: contest,
      home_team: home_team,
      away_team: away_team,
      score1: 4,
      score2: 2,
      points1: 9,
      points2: -9
    )

    render partial: 'matches/list', locals: { matches: [match], friendly: away_team, contest: false }

    doc = Nokogiri::HTML.fragment(rendered)
    headers = doc.css('th').map { |th| th.text.strip }

    expect(headers.index('Points')).to be < headers.index('Score')

    first_row = doc.css('table#matches tr')[1]
    points_cell = first_row.at_css('td.points')
    score_cell = first_row.at_css('td.score')

    expect(first_row.css('td').index(points_cell)).to be < first_row.css('td').index(score_cell)
    expect(points_cell.text).to include('9')
  end
end
