require "rails_helper"

feature "Google Calendar widget", js: :true do
  let(:timezone_name) { Time.zone.name }
  let(:events_data_file) { Rails.root.join("spec/fixtures/google_calendar.json") }
  let(:events_list_data) { JSON.parse(File.read(events_data_file)) }

  before do
    skip # disabling calendar tests for now as they dont fit the new implementation anymore
    visit root_path
  end

  scenario "the most recent upcoming event should appear correctly" do
    time = Time.zone.local(2014, 4, 1, 12, 0, 0)

    Timecop.travel(time) do
      visit root_path

      expect(first_event).to have_content("Div 2B: el'pheer vs. RadicaL")
    end
  end

  feature "Timezones offsets" do
    scenario "when a user is logged out, CEST is default" do
      time = Time.zone.local(2014, 4, 1, 12, 0, 0)

      Timecop.travel(time) do
        visit root_path

        expect(first_event).to have_content("20:30 CEST")
      end
    end

    scenario "when time has passed under 2 hours after the start date" do
      time = Time.zone.local(2014, 4, 4, 23, 59, 0)

      Timecop.travel(time) do
        visit root_path

        expect(first_event).to have_content("Div 3B: Mister vs. HBZ")
      end
    end

    scenario "when time has passed over 2 hours after the start date" do
      time = Time.zone.local(2014, 4, 5, 0, 1, 0)

      Timecop.travel(time) do
        visit root_path

        expect(first_event).not_to have_content("Div 3B: Mister vs. HBZ")
        expect(first_event).to have_content("Div 3B: OMNOM vs. Mister")
      end
    end

    context "when a user is logged in" do
      let(:timezone_name) { "Eastern Time (US & Canada)" }

      before do
        user = create(:user)

        sign_in_as(user)
        change_timezone_for(user, timezone_name)
      end

      scenario "their local timezone is used" do
        time = Time.zone.local(2014, 4, 1, 12, 0, 0)

        Timecop.travel(time) do
          visit root_path

          expect(first_event).to have_content(timezone_adjusted)
        end
      end
    end
  end

  private

  def first_event
    first ".widget.calendar .entry"
  end

  def timezone_adjusted
    if Time.zone.now.dst?
      "14:30 EDT"
    else
      "15:30 EST"
    end
  end
end
