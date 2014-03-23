require 'spec_helper'

feature 'Visitor signs up' do
  let(:user) { attributes_for(:user) }

  before do
    visit new_user_path
  end

  scenario 'with valid Username, Email, Password and Steam ID' do
    fill_form(:user, user.slice(*sign_up_attributes))
    click_button submit(:user, :create)
    
    expect(page).to have_content("Logged in as: #{user[:username]}")
  end

  scenario 'with invalid Email' do
    fill_form(:user, user.slice(*sign_up_attributes).merge({ email: "invalid" }))
    click_button submit(:user, :create)

    expect(page).to have_content(error_message('email.invalid'))
  end

  scenario 'with blank Password' do
    fill_form(:user, user.slice(*sign_up_attributes).merge({ raw_password: "" }))
    click_button submit(:user, :create)

    expect(page).to have_content(error_message('raw_password.blank'))
  end

  scenario 'with invalid Steam ID' do
    fill_form(:user, user.slice(*sign_up_attributes).merge({ steamid: "invalid" }))
    click_button submit(:user, :create)

    expect(page).to have_content(error_message('steamid.invalid'))
  end

  def sign_up_attributes
    [:username, :email, :raw_password, :steamid]
  end

  def error_message(translation)
    I18n.t("activerecord.errors.models.user.attributes.#{translation}")
  end
end
