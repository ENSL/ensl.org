require 'spec_helper'

feature 'Issues' do
	let!(:user) { create :user }

	scenario 'creation' do
		sign_in_as user
		click_link 'Agenda'
		click_link 'Issues'
		click_link 'New issue'
		expect(page).to have_content('New Issue')
		issue_title = 'My Problem'
		issue_description = "There's a fly in my soup"
		fill_in 'Title', with: issue_title
		fill_in 'Text', with: issue_description
		click_button 'Submit'
		expect(page).to have_content('Issue was successfully created.')
		expect(page).to have_content(issue_title)
		expect(page).to have_content(issue_description)
	end	

	feature 'adminstration' do
		let!(:admin) { create :user, :admin }
		let!(:issue) { create :issue, author: user }

		scenario 'issue management' do
			sign_in_as admin
			click_link 'Admin'
			click_link 'Issues (1)'
			within '#open' do
				expect(page).to have_content(issue.title)
				expect(page).to have_content(issue.author.username)
			end
			visit edit_issue_path(issue)
			expect(page).to have_content('Editing Issue')
			solution = "Use a baseball bat"
			fill_in "Title", with: "Foo"
			fill_in "Text", with: "Bar"
			fill_in "Solution", with: solution
			select 'Solved', from: 'Status'
			click_button 'Submit'
			expect(page).to have_content('Issue was successfully updated.')
			visit issues_path
			within '#solved' do
				expect(page).to have_content("Foo")
				expect(page).to have_content(issue.author.username)
			end
		end
	end
end