# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ForumsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user) }
  let(:outsider) { create(:user) }

  def login_as(user)
    post '/users/login', params: { login: { username: user.username, password: user.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /forums' do
    let!(:category) { create(:category, :forums, name: 'Discussion') }
    let!(:public_forum) { create(:forum, category: category, title: 'Public Forum') }
    let!(:private_forum) { create(:forum, category: category, title: 'Private Forum') }
    let!(:group) { create(:group) }

    before do
      create(:forumer, forum: private_forum, group: group, access: Forumer::ACCESS_READ)
      create(:grouper, user: member, group: group)
    end

    it 'shows only public forums to guests' do
      get forums_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Public Forum')
      expect(response.body).not_to include('Private Forum')
    end

    it 'shows accessible private forums to signed-in members' do
      login_as(member)

      get forums_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Public Forum')
      expect(response.body).to include('Private Forum')
    end
  end

  describe 'GET /forums/:id' do
    let!(:public_forum) { create(:forum, title: 'Visible Forum') }
    let!(:private_forum) { create(:forum, title: 'Hidden Forum') }
    let!(:group) { create(:group) }
    let!(:private_topic) { create(:topic, forum: private_forum, title: 'Private Topic') }

    before do
      create(:topic, forum: public_forum, title: 'Visible Topic')
      create(:forumer, forum: private_forum, group: group, access: Forumer::ACCESS_READ)
      create(:grouper, user: member, group: group)
    end

    it 'renders a public forum for guests' do
      get forum_path(public_forum)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Visible Forum')
      expect(response.body).to include('Visible Topic')
    end

    it 'returns 403 for guests on a restricted forum' do
      get forum_path(private_forum)

      expect(response).to have_http_status(:forbidden)
    end

    it 'renders a restricted forum for an allowed member' do
      login_as(member)

      get forum_path(private_forum)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Hidden Forum')
      expect(response.body).to include('Private Topic')
    end
  end

  describe 'GET /forums/new' do
    it 'allows admins to load the new form' do
      login_as(admin)

      get new_forum_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Forum')
    end

    it 'returns 403 for guests' do
      get new_forum_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /forums' do
    let!(:category) { create(:category, :forums) }

    it 'creates a forum for an admin' do
      login_as(admin)

      expect do
        post forums_path,
             params: { forum: { title: 'Created Forum', description: 'Forum body', category_id: category.id } }
      end.to change(Forum, :count).by(1)

      expect(response).to redirect_to(forum_path(Forum.last))
      expect(flash[:notice]).to eq(I18n.t(:forums_create))
    end

    it 're-renders the form for invalid admin input' do
      login_as(admin)
      allow_any_instance_of(Forum).to receive(:save).and_return(false)

      expect do
        post forums_path, params: { forum: { title: '', description: 'Forum body', category_id: category.id } }
      end.not_to change(Forum, :count)

      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      expect do
        post forums_path,
             params: { forum: { title: 'Created Forum', description: 'Forum body', category_id: category.id } }
      end.not_to change(Forum, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /forums/:id/edit' do
    let!(:forum) { create(:forum) }

    it 'allows admins to load the edit form' do
      login_as(admin)

      get edit_forum_path(forum)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Editing forum')
    end

    it 'returns 403 for non-admin users' do
      login_as(outsider)

      get edit_forum_path(forum)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /forums/:id' do
    let!(:forum) { create(:forum, title: 'Old Title') }
    let!(:category) { forum.category }

    it 'updates a forum for an admin' do
      login_as(admin)

      patch forum_path(forum),
            params: { forum: { title: 'New Title', description: 'Updated', category_id: category.id } }

      expect(response).to redirect_to(forum_path(forum))
      expect(forum.reload.title).to eq('New Title')
      expect(flash[:notice]).to eq(I18n.t(:forums_update))
    end

    it 're-renders the edit form for invalid admin input' do
      login_as(admin)
      allow_any_instance_of(Forum).to receive(:update).and_return(false)

      patch forum_path(forum), params: { forum: { title: '', description: 'Updated', category_id: category.id } }

      expect(response).to render_template(:edit)
      expect(forum.reload.title).to eq('Old Title')
    end

    it 'returns 403 for non-admin users' do
      login_as(outsider)

      patch forum_path(forum), params: { forum: { title: 'Blocked' } }

      expect(response).to have_http_status(:forbidden)
      expect(forum.reload.title).to eq('Old Title')
    end
  end

  describe 'PATCH /forums/:id/up' do
    let!(:category) { create(:category, :forums) }
    let!(:first_forum) { Forum.create!(title: 'First Forum', description: 'First description', category: category) }
    let!(:second_forum) { Forum.create!(title: 'Second Forum', description: 'Second description', category: category) }

    it 'moves a forum up for an admin and redirects back' do
      login_as(admin)

      patch up_forum_path(second_forum), headers: { 'HTTP_REFERER' => forums_path }

      expect(response).to redirect_to(forums_path)
      expect(second_forum.reload.position).to be < first_forum.reload.position
    end

    it 'returns 403 for non-admin users' do
      login_as(outsider)

      patch up_forum_path(second_forum), headers: { 'HTTP_REFERER' => forums_path }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /forums/:id/down' do
    let!(:category) { create(:category, :forums) }
    let!(:first_forum) { Forum.create!(title: 'First Forum', description: 'First description', category: category) }
    let!(:second_forum) { Forum.create!(title: 'Second Forum', description: 'Second description', category: category) }

    it 'moves a forum down for an admin and redirects back' do
      login_as(admin)

      patch down_forum_path(first_forum), headers: { 'HTTP_REFERER' => forums_path }

      expect(response).to redirect_to(forums_path)
      expect(first_forum.reload.position).to be > second_forum.reload.position
    end

    it 'returns 403 for non-admin users' do
      login_as(outsider)

      patch down_forum_path(first_forum), headers: { 'HTTP_REFERER' => forums_path }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /forums/:id' do
    let!(:forum) { create(:forum) }

    it 'destroys a forum for an admin' do
      login_as(admin)

      expect do
        delete forum_path(forum)
      end.to change(Forum, :count).by(-1)

      expect(response).to redirect_to(forums_path)
    end

    it 'returns 403 for non-admin users' do
      login_as(outsider)

      expect do
        delete forum_path(forum)
      end.not_to change(Forum, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
