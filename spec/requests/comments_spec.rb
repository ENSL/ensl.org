require 'rails_helper'

RSpec.describe 'CommentsController', type: :request do
  let(:user)  { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:article) { create(:article) }

  def login_as(u)
    post '/users/login', params: { login: { username: u.username, password: u.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  # ---------------------------------------------------------------------------
  # GET /comments
  # ---------------------------------------------------------------------------
  describe 'GET /comments (index)' do
    it 'returns 200 and lists recent non-Issue comments' do
      comment = create(:comment, commentable: article)
      get '/comments'
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
      expect(response.body).to include(comment.text)
    end

    it 'excludes Issue comments from the listing' do
      issue = create(:issue)
      issue_comment = create(:comment, commentable: issue)
      get '/comments'
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(issue_comment.text)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments/:id  (show – rendered as partial for AJAX)
  # ---------------------------------------------------------------------------
  describe 'GET /comments/:id (show)' do
    it 'renders the list partial filtered by commentable' do
      create(:comment, commentable: article)
      get "/comments/#{article.class.name}", params: { id2: article.id }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments/:id/edit
  # ---------------------------------------------------------------------------
  describe 'GET /comments/:id/edit (edit)' do
    let(:comment) { create(:comment, user: user, commentable: article) }

    it 'allows the comment owner to load the edit form' do
      login_as(user)
      get "/comments/#{comment.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'allows an admin to load the edit form for any comment' do
      login_as(admin)
      get "/comments/#{comment.id}/edit"
      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 when a different user tries to edit the comment' do
      other = create(:user)
      login_as(other)
      get "/comments/#{comment.id}/edit"
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 when a guest tries to edit the comment' do
      get "/comments/#{comment.id}/edit"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /comments (create)
  # ---------------------------------------------------------------------------
  describe 'POST /comments (create)' do
    let(:valid_params) do
      { comment: { text: 'Great article!', commentable_type: 'Article', commentable_id: article.id } }
    end

    context 'JS format (the normal in-page create flow)' do
      it 'creates a comment and renders the JS response for an authenticated user' do
        login_as(user)
        expect do
          post '/comments', params: valid_params,
                            headers: { 'ACCEPT' => 'text/javascript' }
        end.to change(Comment, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to match(/javascript/)
        expect(flash[:notice]).to be_present
      end

      it 'does not create a comment for a muted user and returns 403' do
        login_as(user)
        Ban.create!(ban_type: Ban::TYPE_MUTE, expiry: Time.now.utc + 10.days, user_name: user.username)

        expect do
          post '/comments', params: valid_params,
                            headers: { 'ACCEPT' => 'text/javascript' }
        end.not_to change(Comment, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'HTML format' do
      it 'returns 403 when a guest (not logged in) tries to create a comment' do
        expect do
          post '/comments', params: valid_params
        end.not_to change(Comment, :count)

        expect(response).to have_http_status(:forbidden)
      end

      it 'redirects back with a flash error when text is blank' do
        login_as(user)

        expect do
          post '/comments',
               params: { comment: { text: '', commentable_type: 'Article', commentable_id: article.id } }
        end.not_to change(Comment, :count)

        expect(response).to be_redirect
        expect(flash[:error]).to be_present
      end

      it 'redirects back with a flash error when text exceeds max length' do
        login_as(user)

        expect do
          post '/comments',
               params: { comment: { text: 'x' * 10_001, commentable_type: 'Article', commentable_id: article.id } }
        end.not_to change(Comment, :count)

        expect(response).to be_redirect
        expect(flash[:error]).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /comments/:id (update)
  # ---------------------------------------------------------------------------
  describe 'PATCH /comments/:id (update)' do
    let(:comment) { create(:comment, user: user, commentable: article) }

    it 'allows the owner to update their comment and redirects' do
      login_as(user)
      patch "/comments/#{comment.id}", params: { comment: { text: 'Updated text here.' } }
      expect(response).to be_redirect
      expect(comment.reload.text).to eq('Updated text here.')
      expect(flash[:notice]).to be_present
    end

    it 'allows an admin to update any comment and redirects' do
      login_as(admin)
      patch "/comments/#{comment.id}", params: { comment: { text: 'Admin edited this.' } }
      expect(response).to be_redirect
      expect(comment.reload.text).to eq('Admin edited this.')
    end

    it 're-renders the edit form when the new text is invalid (blank)' do
      login_as(user)
      patch "/comments/#{comment.id}", params: { comment: { text: '' } }
      expect(response).to render_template(:edit)
      expect(comment.reload.text).not_to eq('')
    end

    it 'returns 403 when a different non-admin user tries to update' do
      other = create(:user)
      login_as(other)
      patch "/comments/#{comment.id}", params: { comment: { text: 'Sneaky edit.' } }
      expect(response).to have_http_status(:forbidden)
      expect(comment.reload.text).not_to eq('Sneaky edit.')
    end

    it 'returns 403 for a guest' do
      patch "/comments/#{comment.id}", params: { comment: { text: 'Guest edit.' } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /comments/:id (destroy)
  # ---------------------------------------------------------------------------
  describe 'DELETE /comments/:id (destroy)' do
    let!(:comment) { create(:comment, user: user, commentable: article) }

    it 'allows an admin to destroy a comment and redirects' do
      login_as(admin)
      expect do
        delete "/comments/#{comment.id}"
      end.to change(Comment, :count).by(-1)
      expect(response).to be_redirect
    end

    it 'returns 403 and does not destroy when a non-admin tries to delete' do
      login_as(user)
      expect do
        delete "/comments/#{comment.id}"
      end.not_to change(Comment, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 for a guest' do
      expect do
        delete "/comments/#{comment.id}"
      end.not_to change(Comment, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments/quote
  # ---------------------------------------------------------------------------
  describe 'GET /comments/quote (quote)' do
    let!(:comment) { create(:comment, user: user, commentable: article) }

    it 'renders the quote template for a logged-in user' do
      login_as(user)
      get '/comments/quote', params: { id: comment.id }
      expect(response).to have_http_status(:ok)
    end
  end
end
