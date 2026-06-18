# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MoviesController', type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:user) { create(:user) }
  let!(:movie) { create(:movie, user: admin) }

  describe 'GET /movies' do
    it 'renders the archive listing' do
      get '/movies'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
    end
  end

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'GET /movies/admin' do
    it 'renders make preview as a POST link action' do
      movie.update!(web_friendly: false, preview: nil)
      login_as(admin)

      get '/movies/admin'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("href=\"/movies/#{movie.id}/preview\"")
      expect(response.body).to match(/(?:data-method|data-turbo-method)="post"/)
    end

    it 'returns 403 for non-admin users' do
      get '/movies/admin'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /movies/new' do
    it 'renders the new form for admins' do
      login_as(admin)

      get '/movies/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for anonymous users' do
      get '/movies/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /movies' do
    before do
      login_as(admin)
    end

    it 'creates a movie and redirects to it when valid' do
      expect do
        post '/movies', params: {
          movie: {
            name: 'Request Created Movie',
            content: 'Created from request spec',
            length: 120,
            category_id: movie.category_id,
            user_id: admin.id
          }
        }
      end.to change(Movie, :count).by(1)

      expect(response).to redirect_to(movie_path(Movie.order(:id).last))
    end

    it 're-renders new when validation fails' do
      expect do
        post '/movies', params: {
          movie: {
            name: 'Broken Movie',
            length: -1,
            category_id: movie.category_id,
            user_id: admin.id
          }
        }
      end.not_to change(Movie, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
    end
  end

  describe 'POST /movies/:id/preview' do
    before do
      login_as(admin)
    end

    it 'handles video processing errors without raising and redirects with alert' do
      allow_any_instance_of(Movie).to receive(:make_preview).and_raise(VideoProcessing::InvalidInput, 'Input not found')

      post "/movies/#{movie.id}/preview"

      expect(response).to redirect_to(movie_path(movie))
      expect(flash[:alert]).to eq('Input not found')
    end

    it 'sets a success notice when preview generation succeeds' do
      allow_any_instance_of(Movie).to receive(:make_preview).and_return('/tmp/test_preview.mp4')

      post "/movies/#{movie.id}/preview"

      expect(response).to redirect_to(movie_path(movie))
      expect(flash[:notice]).to include(I18n.t(:executed))
      expect(flash[:notice]).to include('/tmp/test_preview.mp4')
    end

    it 'renders a turbo-stream notice on success' do
      allow_any_instance_of(Movie).to receive(:make_preview).and_return('/tmp/test_preview.mp4')

      post "/movies/#{movie.id}/preview", headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('turbo-stream')
      expect(response.body).to include(I18n.t(:executed))
    end

    it 'renders a turbo-stream alert on failure' do
      allow_any_instance_of(Movie).to receive(:make_preview).and_raise(VideoProcessing::InvalidInput, 'Input not found')

      post "/movies/#{movie.id}/preview", headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('turbo-stream')
      expect(response.body).to include('Input not found')
    end
  end

  describe 'PATCH /movies/:id' do
    before do
      login_as(admin)
    end

    it 'does not clear existing file when file_id is submitted blank' do
      original_file_id = movie.file_id

      patch "/movies/#{movie.id}", params: {
        movie: {
          content: 'updated content',
          file_id: ''
        }
      }

      expect(response).to redirect_to(movie_path(movie))
      expect(movie.reload.file_id).to eq(original_file_id)
      expect(movie.content).to eq('updated content')
    end

    it 're-renders edit when the payload is invalid' do
      patch "/movies/#{movie.id}", params: { movie: { length: -1 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:edit)
    end
  end

  describe 'GET /movies/:id' do
    it 'renders successfully when movie has no file' do
      login_as(admin)
      movie.update!(file: nil)

      get "/movies/#{movie.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'redirects to the related data file when one is attached' do
      related_file = create(:data_file, directory: movie.file.directory, title: 'Related target')
      movie.file.update!(related: related_file)

      get "/movies/#{movie.id}"

      expect(response).to redirect_to(data_file_path(related_file))
    end
  end

  describe 'GET /movies/:id/edit' do
    it 'renders successfully when movie has no file' do
      login_as(admin)
      movie.update!(file: nil)

      get "/movies/#{movie.id}/edit"

      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 for unauthorized users' do
      login_as(user)

      get "/movies/#{movie.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /movies/:id/snapshot' do
    before do
      login_as(admin)
    end

    it 'redirects with a notice when snapshot creation succeeds' do
      allow_any_instance_of(Movie).to receive(:make_snapshot).with(seconds: 12.5).and_return(true)

      post "/movies/#{movie.id}/snapshot", params: { secs: '12.5' }

      expect(response).to redirect_to(edit_movie_path(movie))
      expect(flash[:notice]).to eq('Snapshot created.')
    end

    it 'redirects with an alert when snapshot creation fails' do
      allow_any_instance_of(Movie).to receive(:make_snapshot).with(seconds: nil).and_return(false)

      post "/movies/#{movie.id}/snapshot", params: { secs: '-2' }

      expect(response).to redirect_to(edit_movie_path(movie))
      expect(flash[:alert]).to eq('Snapshot could not be created.')
    end

    it 'renders a turbo-stream notice when snapshot creation succeeds' do
      allow_any_instance_of(Movie).to receive(:make_snapshot).with(seconds: nil).and_return(true)

      post "/movies/#{movie.id}/snapshot", headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('Snapshot created.')
    end

    it 'renders a turbo-stream alert when snapshot creation fails' do
      allow_any_instance_of(Movie).to receive(:make_snapshot).with(seconds: nil).and_return(false)

      post "/movies/#{movie.id}/snapshot", headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('Snapshot could not be created.')
    end

    it 'returns 403 for unauthorized users' do
      login_as(user)

      post "/movies/#{movie.id}/snapshot"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /movies/:id/download' do
    it 'returns 403 for anonymous users' do
      get "/movies/#{movie.id}/download"

      expect(response).to have_http_status(:forbidden)
    end

    it 'renders the execution result for admins' do
      login_as(admin)
      allow_any_instance_of(Movie).to receive(:make_stream).and_return('stream started')

      get "/movies/#{movie.id}/download", params: { ip: '127.0.0.1', port: '1234' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t(:executed))
      expect(response.body).to include('stream started')
    end
  end

  describe 'DELETE /movies/:id' do
    it 'destroys the movie and redirects to the archive' do
      login_as(admin)

      expect do
        delete "/movies/#{movie.id}"
      end.to change(Movie, :count).by(-1)

      expect(response).to redirect_to(movies_url)
    end

    it 'returns 403 for unauthorized users' do
      login_as(user)

      expect do
        delete "/movies/#{movie.id}"
      end.not_to change(Movie, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
