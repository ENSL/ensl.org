require 'rails_helper'

RSpec.describe 'TopicsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:outsider) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /topics' do
    let!(:public_forum) { create(:forum) }
    let!(:private_forum) { create(:forum) }
    let!(:group) { create(:group) }
    let!(:public_topic) { create(:topic, forum: public_forum, title: 'Public Topic') }
    let!(:private_topic) { create(:topic, forum: private_forum, title: 'Private Topic') }

    before do
      create(:forumer, forum: private_forum, group: group, access: Forumer::ACCESS_READ)
    end

    it 'lists recent public topics only' do
      get topics_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Public Topic')
      expect(response.body).not_to include('Private Topic')
    end
  end

  describe 'GET /topics/:id' do
    let!(:public_forum) { create(:forum) }
    let!(:private_forum) { create(:forum) }
    let!(:group) { create(:group) }
    let!(:public_topic) { create(:topic, forum: public_forum, title: 'Visible Topic') }
    let!(:private_topic) { create(:topic, forum: private_forum, title: 'Hidden Topic') }

    before do
      create(:forumer, forum: private_forum, group: group, access: Forumer::ACCESS_READ)
    end

    it 'renders a public topic for guests and records the view as logged out' do
      expect do
        get topic_path(public_topic)
      end.to change(ViewCount, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Visible Topic')
      expect(public_topic.reload.view_counts.last.logged_in).to be(false)
    end

    it 'renders a public topic for signed-in users and records the view as logged in' do
      login_as(user)

      expect do
        get topic_path(public_topic)
      end.to change(ViewCount, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(public_topic.reload.view_counts.last.logged_in).to be(true)
    end

    it 'returns 403 for guests on a restricted topic' do
      get topic_path(private_topic)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /topics/new' do
    let!(:forum) { create(:forum) }

    it 'allows authenticated users to load the form' do
      login_as(user)

      get new_topic_path, params: { id: forum.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Topic')
    end

    it 'returns 403 for guests' do
      get new_topic_path, params: { id: forum.id }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /topics' do
    let!(:forum) { create(:forum) }

    it 'creates a topic and first post for an authenticated user' do
      login_as(user)

      expect do
        post topics_path, params: { topic: { title: 'Created Topic', first_post: 'Opening post', forum_id: forum.id } }
      end.to change(Topic, :count).by(1).and change(Post, :count).by(1)

      expect(response).to redirect_to(topic_path(Topic.last))
      expect(Topic.last.user).to eq(user)
      expect(flash[:notice]).to eq(I18n.t(:topics_create))
    end

    it 're-renders the form for invalid input' do
      login_as(user)

      expect do
        post topics_path, params: { topic: { title: '', first_post: 'Opening post', forum_id: forum.id } }
      end.not_to change(Topic, :count)

      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      expect do
        post topics_path, params: { topic: { title: 'Created Topic', first_post: 'Opening post', forum_id: forum.id } }
      end.not_to change(Topic, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /topics/:id/edit' do
    let!(:topic) { create(:topic) }

    it 'allows admins to load the edit form' do
      login_as(admin)

      get edit_topic_path(topic)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Editing Topic')
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get edit_topic_path(topic)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /topics/:id' do
    let!(:topic) { create(:topic, title: 'Old Title', state: Topic::STATE_NORMAL) }

    it 'updates a topic for an admin' do
      login_as(admin)

      patch topic_path(topic), params: { topic: { title: 'New Title', forum_id: topic.forum_id, state: Topic::STATE_STICKY } }

      expect(response).to redirect_to(topic_path(topic))
      expect(topic.reload.title).to eq('New Title')
      expect(topic.state).to eq(Topic::STATE_STICKY)
      expect(flash[:notice]).to eq(I18n.t(:topics_update))
    end

    it 're-renders the edit form for invalid admin input' do
      login_as(admin)

      patch topic_path(topic), params: { topic: { title: '', forum_id: topic.forum_id, state: Topic::STATE_NORMAL } }

      expect(response).to render_template(:edit)
      expect(topic.reload.title).to eq('Old Title')
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      patch topic_path(topic), params: { topic: { title: 'Blocked', forum_id: topic.forum_id } }

      expect(response).to have_http_status(:forbidden)
      expect(topic.reload.title).to eq('Old Title')
    end
  end

  describe 'DELETE /topics/:id' do
    let!(:topic) { create(:topic) }

    it 'destroys a topic for an admin' do
      login_as(admin)

      expect do
        delete topic_path(topic)
      end.to change(Topic, :count).by(-1)

      expect(response).to redirect_to(topics_path)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      expect do
        delete topic_path(topic)
      end.not_to change(Topic, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
