require "spec_helper"

feature "Visitor signs up", js: :true do
  let(:user) { attributes_for(:user) }

  before do
    visit new_user_path
  end

  scenario "with valid Username, Email, Password and Steam ID" do
    within registration_form do
      fill_form(:user, user.slice(*sign_up_attributes))
      click_button submit(:user, :create)
    end

    expect(user_status).to have_content("ACCOUNT")
  end

  scenario "with invalid Email" do
    within registration_form do
      fill_form(:user, user.slice(*sign_up_attributes).merge(email: "invalid"))
      click_button submit(:user, :create)
    end

    expect(page).to have_content(error_message("email.invalid"))
  end

  scenario "with blank Password" do
    within registration_form do
      fill_form(:user, user.slice(*sign_up_attributes).merge(raw_password: ""))
      click_button submit(:user, :create)
    end

    expect(page).to have_content(error_message("raw_password.blank"))
  end

  scenario "with invalid Steam ID" do
    within registration_form do
      fill_form(:user, user.slice(*sign_up_attributes).merge(steamid: "invalid"))
      click_button submit(:user, :create)
    end

    expect(page).to have_content(error_message("steamid.invalid"))
  end

  scenario "with out of range Steam ID" do
    within registration_form do
      fill_form(:user, user.slice(*sign_up_attributes).merge(steamid: "0:0:2147483648"))
      click_button submit(:user, :create)
    end

    expect(page).to have_content(error_message("steamid.invalid"))
  end

  scenario "with nil Steam ID" do
    within registration_form do
      fill_form(:user, user.slice(*sign_up_attributes).merge(steamid: nil))
      click_button submit(:user, :create)
    end

    expect(page).to have_content(error_message("steamid.invalid"))
  end

  def sign_up_attributes
    [:username, :email, :raw_password, :steamid]
  end

  def error_message(translation)
    I18n.t("activerecord.errors.models.user.attributes.#{translation}")
  end
end
