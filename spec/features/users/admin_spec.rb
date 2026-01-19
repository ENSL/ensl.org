require 'rails_helper'

feature "Admin logs in", js: :true do
  let(:user) { attributes_for(:user) }

  before do
    visit new_user_path
  end

end
