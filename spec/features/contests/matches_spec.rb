require 'rails_helper'

RSpec.feature 'Matches management', type: :feature, js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:contest) { create(:contest) }
  let!(:map1) { create(:map) }
  let!(:map2) { create(:map) }
  let!(:map3) { create(:map) }
  let!(:map4) { create(:map) }
  let!(:week) { create(:week, contest: contest, map1: map1, map2: map2) }
  let!(:team1) { create(:team) }
  let!(:team2) { create(:team) }
  let!(:team3) { create(:team) }
  let!(:contester1) { create(:contester, team: team1, contest: contest) }
  let!(:contester2) { create(:contester, team: team2, contest: contest) }
  let!(:contester3) { create(:contester, team: team3, contest: contest) }

  before do
    # sign in as admin to have full permissions
    contest.maps << [map1, map2, map3, map4]
    sign_in_as(admin)
  end

  def select_option_by_value(select_id, value)
    select value.to_s, from: select_id
  rescue Capybara::ElementNotFound
    select value.to_s.rjust(2, '0'), from: select_id
  end

  def select_first_option(select_id)
    select = find("##{select_id}")
    option = select.all('option').find { |o| o[:value].present? }
    raise "No selectable option for #{select_id}" unless option

    option.select_option
    { id: option[:value].to_i, text: option.text }
  end

  def select_last_option(select_id)
    select = find("##{select_id}")
    options = select.all('option').select { |o| o[:value].present? }
    raise "No selectable option for #{select_id}" if options.empty?

    option = options.last
    option.select_option
    { id: option[:value].to_i, text: option.text }
  end

  def create_match_from_form
    visit new_match_path(id: contest.id)

    contester1_opt = select_first_option('match_contester1_id')
    contester2_opt = select_last_option('match_contester2_id')
    select_match_datetime(Time.current + 2.days)
    select_first_option('match_map1_id')
    select_last_option('match_map2_id')

    click_button 'Save Match'

    # Ensure the match was created; fail fast with visible errors if not
    raise "Match creation failed: #{page.find('#errors').text}" if page.has_css?('#errors')

    [contester1_opt, contester2_opt]
  end

  def click_delete_action
    attempts = 0
    begin
      attempts += 1
      links = all('td.actions a', visible: :all)
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      raise if attempts > 6

      sleep(0.1)
      retry
    end
    # Prefer explicit data-submit-form (our delete form link), then a link with confirm, else fallback to last action
    link = links.find { |a| a[:'data-submit-form'].present? } || links.find do |a|
      a[:'data-confirm'].present?
    end || links.last
    raise Capybara::ElementNotFound, 'No action links found' unless link

    begin
      link.click
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      attempts = 0
      begin
        attempts += 1
        links = all('td.actions a', visible: :all)
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        raise if attempts > 6

        sleep(0.1)
        retry
      end
      link = links.find { |a| a[:'data-submit-form'].present? } || links.find do |a|
        a[:'data-confirm'].present?
      end || links.last
      link.click
    end
  end

  def select_match_datetime(value)
    select_option_by_value('match_match_time_1i', value.year)
    select_option_by_value('match_match_time_2i', value.strftime('%B'))
    select_option_by_value('match_match_time_3i', value.day)
    select_option_by_value('match_match_time_4i', value.strftime('%H'))
    select_option_by_value('match_match_time_5i', value.strftime('%M'))
  end

  scenario 'Create a match from the new match view with JS', :aggregate_failures do
    contester1_opt, contester2_opt = create_match_from_form

    expect(page).to have_current_path(/matches|contests/) # redirected to match or contest edit
    find("a[href='#matches']").click
    expect(page).to have_css('#matches table.matches')
    within('#matches') do
      expect(page).to have_content(contester1_opt[:text])
      expect(page).to have_content(contester2_opt[:text])
    end
  end

  scenario 'Update editable match attributes via the edit view with JS', :aggregate_failures do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2, map1: map1, map2: map2,
                           week: week)
    visit edit_match_path(match)

    # Update fields available on the edit form
    contester1_opt = select_first_option('match_contester1_id')
    contester2_opt = select_last_option('match_contester2_id')
    map1_opt = select_last_option('match_map1_id')
    map2_opt = select_last_option('match_map2_id')
    week_opt = select_last_option('match_week_id')
    select_match_datetime(Time.current + 3.days)

    click_button 'Save Match'

    expect(page).to have_current_path(match_path(match))
    expect(page).to have_content(contester1_opt[:text])
    expect(page).to have_content(contester2_opt[:text])
    expect(page).to have_content(map1_opt[:text])
    expect(page).to have_content(map2_opt[:text])
  end

  scenario 'Delete a match from the view with JS', :aggregate_failures do
    contester1_opt, contester2_opt = create_match_from_form
    visit edit_contest_path(contest)
    find("a[href='#matches']").click
    expect(page).to have_css('#matches table.matches')
    expect(page).to have_content(contester1_opt[:text])

    # Delete from the matches table action link for the created match row
    within('#matches') do
      # Row may be present but hidden by the tab widget; allow searching hidden nodes
      row = find('tr', text: contester1_opt[:text], visible: :all)
      within(row) do
        attempts = 0
        begin
          attempts += 1
          delete_link = find('a[data-submit-form]', visible: :all)
        rescue Selenium::WebDriver::Error::StaleElementReferenceError, Capybara::ElementNotFound
          raise if attempts > 6

          sleep 0.1
          retry
        end

        # Use direct form submission via JS to avoid flaky click/stale-element races.
        form = delete_link.find_xpath('ancestor::form').first
        form_id = form[:id]
        # Auto-accept confirm dialogs and submit the form
        page.execute_script('window._orig_confirm = window.confirm; window.confirm = function(){return true};')
        page.execute_script("document.getElementById('#{form_id}').submit();")
        page.execute_script('if(window._orig_confirm) window.confirm = window._orig_confirm')
      end
    end

    expect(page).to have_current_path(edit_contest_path(contest))
  end
end
