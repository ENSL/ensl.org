require 'spec_helper'

feature 'Google Calendar widget' do
  let(:time) { Time.zone.local(2014, 4, 1, 12, 0, 0) }
  let(:events_list_json) { JSON.parse(File.read(Rails.root.join('spec/fixtures/google_calendar.json'))) }
  let!(:user) { create(:user) }

  before do
    Timecop.travel(time)

    GoogleCalendar::Request.stub(:events_list) do
      GoogleCalendar::EventList.new(events_list_json, Time.zone.name)
    end

    visit root_path
  end

  scenario 'the most recent upcoming event should appear correctly' do
    expect(first_event).to have_content("Div 2B: el'pheer vs. RadicaL")
  end

  feature 'Timezones offsets' do
    scenario 'when a user is logged out, CEST is default' do
      expect(first_event).to have_content("20:30 CEST")
    end

    scenario 'when a user is logged in, their local timezone is used' do
      sign_in_as(user)
      change_timezone_for(user, timezone_us_east)
      visit root_path

      expect(first_event).to have_content(timezone_adjusted)
    end
  end

  private

  def first_event
    page.find(:xpath, "//div[@id = 'index-calendar']/div/div[@class = 'content'][1]")
  end

  def timezone_adjusted
    if Time.now.dst?
      "14:30 EDT"
    else
      "15:30 EST"
    end
  end

  def timezone_us_east
    "Eastern Time (US & Canada)"
  end
end