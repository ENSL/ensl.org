require "rails_helper"

feature "User Stream Information" do
  let(:password) { "foobar" }
  let!(:user) { create :user, raw_password: password }

  feature "stream administration" do
    scenario "user updates their stream" do
      visit user_path(user)
      expect(page.html).to_not include("<dt>Stream</dt>")
      sign_in_as(user)
      visit edit_user_path(user)
      stream_url = "twitch.tv/gold_n"
      expect(page).to have_content("Stream")
      fill_in "user_profile_attributes_stream", with: stream_url
      click_button "Update Profile"
      expect(page).to have_content(I18n.t(:users_update))
      visit user_path(user)
      expect(page.html).to include("<dt>Stream</dt>")
      expect(page).to have_content(stream_url)
    end
  end

  def fill_login_form(user, password)
    fill_in "login_username", with: user.username
    fill_in "login_password", with: password
  end
end
