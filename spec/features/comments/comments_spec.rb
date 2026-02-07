require 'rails_helper'

feature 'Comments feature', js: true do
  # Needs to be admin to create published articles
	let!(:author) { create(:user, :admin) }
	let!(:commenter) { create(:user) }

	describe 'Article comments' do
		let!(:category) { create(:category, domain: Category::DOMAIN_ARTICLES) }
		let!(:article) { create(:article, user: author, category: category, status: Article::STATUS_PUBLISHED) }

		before do
			sign_in_as(commenter)
			visit article_path(article)
		end

		it 'allows a signed-in user to post a comment' do
			within '#reply' do
				find('textarea').set('Great article!')
				click_button 'Post Comment'
			end

			expect(page).to have_content('Great article!')
			expect(page).to have_content(commenter.username)
		end
	end

	describe 'Match comments' do
		let!(:match) { create(:match) }

		before do
			sign_in_as(commenter)
			visit match_path(match)
		end

		it 'allows posting a comment on a match' do
			within '#reply' do
				find('textarea').set('Good luck!')
				click_button 'Post Comment'
			end

			expect(page).to have_content('Good luck!')
			expect(page).to have_content(commenter.username)
		end
	end
end

