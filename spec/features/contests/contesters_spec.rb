# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Contesters (teams) management', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:team) { create(:team) }

  before do
    sign_in_as(admin)
    visit edit_contest_path(contest, anchor: 'teams')
    expect(page).to have_css('#teams')
  end

  scenario 'Add a contester (team) to contest', :aggregate_failures do
    within('#teams') do
      form = find('form')
      select_el = form.find('select')
      option = select_el.find('option', text: team.name)
      option.select_option
      form.find('input[type=submit]').click
    end

    expect(page).to have_current_path(/contests/)
    visit edit_contest_path(contest, anchor: 'teams')
    # verify table headers and the added team's row values
    within('#teams table.teams') do
      expect(page).to have_css('thead') if page.has_css?('thead')
      # header columns (Team, Score, Win, Loss, Draw, Bonus, Status)
      expect(page).to have_css('th.team')
      expect(page).to have_css('th.score')
      expect(page).to have_css('th.win')
      expect(page).to have_css('th.loss')
      expect(page).to have_css('th.draw')
      expect(page).to have_css('th.extra')
      expect(page).to have_css('th.status')

      # reload to pick up the newly-created contester and its defaults
      created = contest.reload.contesters.find_by(team: team)
      row = find('tr', text: team.name)
      cells = row.all('td')
      expect(cells[0]).to have_link(team.name)
      expect(cells[1]).to have_text(created.score.to_s)
      expect(cells[2]).to have_text(created.win.to_s)
      expect(cells[3]).to have_text(created.loss.to_s)
      expect(cells[4]).to have_text(created.draw.to_s)
      expect(cells[5]).to have_text(created.extra.to_s)
    end
  end

  scenario 'Edit contester and return to contest teams tab', :aggregate_failures do
    contester = create(:contester, contest: contest, team: team)
    visit edit_contester_path(contester)

    # The edit page should have a back link to contest teams
    expect(page).to have_link('Back to contest', href: edit_contest_path(contester.contest, anchor: 'teams'))

    fill_in 'contester_score', with: contester.score.to_i + 1
    click_button 'Save Contester'

    expect(page).to have_current_path(%r{/contests/[0-9]+/edit}) # accept edit path with/without fragment
    visit edit_contest_path(contest, anchor: 'teams')
    expect(page).to have_css('#teams table.teams')
    # verify the contester row shows correct column values
    within('#teams table.teams') do
      contester.reload
      row = find('tr', text: contester.team.name)
      cells = row.all('td')
      expect(cells[0]).to have_link(contester.team.name)
      expect(cells[1]).to have_text(contester.score.to_s)
      expect(cells[2]).to have_text(contester.win.to_s)
      expect(cells[3]).to have_text(contester.loss.to_s)
      expect(cells[4]).to have_text(contester.draw.to_s)
      expect(cells[5]).to have_text(contester.extra.to_s)
      # status column text should match the model's status mapping
      expect(cells[6]).to have_text(contester.statuses[contester.active])
    end
  end

  scenario 'Delete contester from contest teams', :aggregate_failures do
    visit edit_contest_path(contest, anchor: 'teams')
    expect(page).to have_css('#teams table.teams')

    within('#teams') do
      form = find('form')
      select_el = form.find('select')
      select_el.find('option', text: team.name).select_option
      form.find('input[type=submit]').click
    end

    expect(page).to have_current_path(%r{/contests/[0-9]+/edit(?:#teams)?})
    expect(page).to have_css('#teams table.teams', text: team.name, wait: 5)
    contester = contest.reload.contesters.find_by!(team: team)

    # Delete from the teams table action link for the created team row
    within('#teams') do
      row = find('tr', text: contester.team.name, visible: :all)
      within(row) do
        accept_confirm do
          find("a[data-method='delete']").click
        end
      end
    end

    expect(page).to have_current_path(edit_contest_path(contest))
    expect(page).to have_text(I18n.t('contests.contester.destroy'))
    contester.reload
    expect(contester.active).to be(false)
    expect(Contester.active.exists?(contester.id)).to be(false)

    # ensure we have a fresh rendering of the contest edit page (avoid stale client DOM)
    visit edit_contest_path(contest, anchor: 'teams')
    within('#teams table.teams') do
      expect(page).not_to have_text(contester.team.name)
    end
  end
end
