require 'rails_helper'

feature 'Gathers', js: true do
	let!(:user) { create :user }
	let!(:gather) { create :gather, :running }

  background do
    sign_in_as user
  end

  scenario 'Try to join without checking TOS' do
    visit gather_path(gather)

    find('a#gatherJoinBtn').trigger('click')

    # TODO: check error
    expect(page).to have_content("Confirm must be accepted")
    expect(gather.gatherers.count).to eq(0)
  end

  scenario 'Join (1 player)' do
    visit gather_path(gather)

    check 'gatherer[confirm]'
    find('a#gatherJoinBtn').trigger('click')

    expect(page).to have_content(I18n.t(:gathers_join))
    expect(gather.gatherers.count).to eq(1)
    expect(gather.gatherers.last.user_id).to eq(user.id)
  end 

  # NOTE: this might break due to afk kicker
  scenario 'Join (12 players)' do
    sign_out

    expect(gather.status).to eq(Gather::STATE_RUNNING)

    users = create_list(:user, 11)
    users << user
    users.each do |u|
      sign_in_as u

      visit gather_path(gather)
      check 'gatherer[confirm]'
      find('a#gatherJoinBtn').trigger('click')

      expect(page).to have_content(I18n.t(:gathers_join))
      expect(gather.gatherers.last.user_id).to eq(u.id)
      sign_out
    end

    expect(gather.gatherers.count).to eq(12)
    # expect(gather.status).to eq(Gather::STATE_VOTING)

    sign_in_as user
    visit gather_path(gather)
    # sleep(90)
  end
end