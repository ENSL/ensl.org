# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoviesController, type: :controller do
  render_views

  let!(:admin) { create(:user, :admin) }
  let!(:movie) { create(:movie, user: admin) }

  describe 'GET #admin' do
    it 'renders make preview as a POST link action' do
      movie.update!(web_friendly: false, preview: nil)
      login_admin

      get :admin

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("href=\"/movies/#{movie.id}/preview\"")
      expect(response.body).to match(/(?:data-method|data-turbo-method)="post"/)
    end
  end

  describe 'POST #preview' do
    it 'handles video processing errors without raising and redirects with alert' do
      login_admin
      allow(Movie).to receive(:find).with(movie.id.to_s).and_return(movie)
      allow(movie).to receive(:make_preview).and_raise(VideoProcessing::InvalidInput, 'Input not found')

      post :preview, params: { id: movie.id }

      expect(response).to redirect_to(movie_path(movie))
      expect(flash[:alert]).to eq('Input not found')
    end

    it 'sets a success notice when preview generation succeeds' do
      login_admin
      allow(Movie).to receive(:find).with(movie.id.to_s).and_return(movie)
      allow(movie).to receive(:make_preview).and_return('/tmp/test_preview.mp4')

      post :preview, params: { id: movie.id }

      expect(response).to redirect_to(movie_path(movie))
      expect(flash[:notice]).to include(I18n.t(:executed))
      expect(flash[:notice]).to include('/tmp/test_preview.mp4')
    end
  end

  describe 'PATCH #update' do
    it 'does not clear existing file when file_id is submitted blank' do
      login_admin
      original_file_id = movie.file_id

      patch :update, params: {
        id: movie.id,
        movie: {
          content: 'updated content',
          file_id: ''
        }
      }

      expect(response).to redirect_to(movie_path(movie))
      expect(movie.reload.file_id).to eq(original_file_id)
      expect(movie.content).to eq('updated content')
    end
  end

  describe 'GET #show' do
    it 'renders successfully when movie has no file' do
      login_admin
      movie.update!(file: nil)

      get :show, params: { id: movie.id }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #edit' do
    it 'renders successfully when movie has no file' do
      login_admin
      movie.update!(file: nil)

      get :edit, params: { id: movie.id }

      expect(response).to have_http_status(:ok)
    end
  end
end
