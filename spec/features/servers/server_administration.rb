require 'spec_helper'

feature 'Server Administration' do
	let!(:admin) { create :user, :admin }  

	background do
		sign_in_as admin
	end

	scenario 'creating a server' do
		visit servers_path
		expect(page).to have_content('Listing Servers')
		click_link 'New server'
		test_server_creation_and_editing
		visit servers_path
		expect(page).to have_content Server.last.name
	end

	feature 'Server deletion' do
		let!(:server) { create :server }
		scenario 'deleting a server' do
			visit servers_path
			expect(page).to have_content(server.name)
			visit server_path(server)
			click_link 'Delete Server'
			visit servers_path
			expect(page).to_not have_content(server.name)
		end
	end
end
