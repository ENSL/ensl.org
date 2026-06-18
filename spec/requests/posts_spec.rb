require 'rails_helper'

RSpec.describe 'PostsController', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:outsider) { create(:user) }
  let(:forum) { create(:forum) }
  let(:topic) { create(:topic, forum: forum, user: user) }

  describe 'GET /posts/:id/quote' do
    it 'renders when the post can be shown' do
      post_record = create(:post, topic: topic, user: user)
      login_as(user)
      allow_any_instance_of(Post).to receive(:can_show?).and_return(true)

      get "/posts/#{post_record.id}/quote",
          headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'ACCEPT' => 'text/javascript' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/javascript')
    end

    it 'returns 403 when the post cannot be shown' do
      post_record = create(:post, topic: topic, user: user)
      login_as(outsider)
      allow_any_instance_of(Post).to receive(:can_show?).and_return(false)

      get "/posts/#{post_record.id}/quote"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /posts/new' do
    it 'allows authenticated users' do
      login_as(user)

      get '/posts/new', params: { id: topic.id }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      get '/posts/new', params: { id: topic.id }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /posts/:id/edit' do
    it 'allows the post owner' do
      post_record = create(:post, topic: topic, user: user)
      login_as(user)

      get "/posts/#{post_record.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for other users' do
      post_record = create(:post, topic: topic, user: user)
      login_as(outsider)

      get "/posts/#{post_record.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /posts' do
    it 'creates a post and redirects for html requests' do
      login_as(user)
      topic

      expect do
        post '/posts', params: { post: { topic_id: topic.id, text: 'Created from request spec' } }
      end.to change(Post, :count).by(1)

      created_post = Post.order(:id).last
      expect(response).to redirect_to(topic_path(topic, anchor: "post_#{created_post.id}"))
    end

    it 'renders new when the html payload is invalid' do
      login_as(user)
      topic

      expect do
        post '/posts', params: { post: { topic_id: topic.id, text: '' } }
      end.not_to change(Post, :count)

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'renders javascript on success for xhr requests' do
      login_as(user)
      topic

      post '/posts',
           params: { post: { topic_id: topic.id, text: 'XHR created post' } },
           headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'ACCEPT' => 'text/javascript' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/javascript')
    end

    it 'renders the create_error template for invalid xhr requests' do
      login_as(user)
      topic

      post '/posts',
           params: { post: { topic_id: topic.id, text: '' } },
           headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'ACCEPT' => 'text/javascript' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/javascript')
      expect(response).to render_template(:create_error)
    end

    it 'returns 403 for guests' do
      topic

      expect do
        post '/posts', params: { post: { topic_id: topic.id, text: 'Blocked' } }
      end.not_to change(Post, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /posts/:id' do
    it 'updates the post for its owner' do
      post_record = create(:post, topic: topic, user: user, text: 'Before')
      login_as(user)

      patch "/posts/#{post_record.id}", params: { post: { text: 'After', topic_id: topic.id } }

      expect(response).to redirect_to(topic_path(topic, anchor: "post_#{post_record.id}"))
      expect(post_record.reload.text).to eq('After')
    end

    it 're-renders edit when the update is invalid' do
      post_record = create(:post, topic: topic, user: user, text: 'Before')
      login_as(user)

      patch "/posts/#{post_record.id}", params: { post: { text: '', topic_id: topic.id } }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
      expect(post_record.reload.text).to eq('Before')
    end

    it 'returns 403 for other users' do
      post_record = create(:post, topic: topic, user: user)
      login_as(outsider)

      patch "/posts/#{post_record.id}", params: { post: { text: 'Blocked', topic_id: topic.id } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /posts/:id' do
    it 'redirects back to the topic when it remains after deletion' do
      create(:post, topic: topic, user: user, text: 'Keep topic alive')
      doomed_post = create(:post, topic: topic, user: user, text: 'Delete me')
      login_as(admin)

      expect do
        delete "/posts/#{doomed_post.id}"
      end.to change(Post, :count).by(-1)

      expect(response).to redirect_to('/')
    end

    it 'redirects to the forum when deleting the last post destroys the topic' do
      doomed_topic = create(:topic, forum: forum, user: user)
      doomed_post = doomed_topic.posts.first
      login_as(admin)

      expect do
        delete "/posts/#{doomed_post.id}"
      end.to change(Post, :count).by(-1)

      expect(response).to redirect_to('/')
    end

    it 'returns 403 for non-admin users' do
      post_record = create(:post, topic: topic, user: user)
      login_as(user)

      delete "/posts/#{post_record.id}"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
