require 'spec_helper'

feature 'User creates new article' do
  let(:user) { create(:user) }
  let(:article) { attributes_for(:article) }

  before do
    visit new_article_path
  end

  describe 'with valid Title, Content: ' do
    describe ''
  end
end
