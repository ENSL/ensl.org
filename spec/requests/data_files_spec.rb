# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DataFilesController', type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  def ensure_root_directory
    Directory.find_or_create_by!(id: Directory::ROOT) do |dir|
      dir.name = 'root'
      dir.title = 'Root'
      dir.hidden = false
      dir.path = ENV.fetch('FILES_ROOT')
    end
  end

  def ensure_movies_directory
    Directory.find_or_create_by!(id: Directory::MOVIES) do |dir|
      dir.name = 'movies'
      dir.title = 'Movies'
      dir.parent = ensure_root_directory
    end
  end

  before do
    ENV['FILES_ROOT'] = File.join(Dir.tmpdir, 'ensl_data_files_request_spec')
    FileUtils.rm_rf(ENV['FILES_ROOT'])
    FileUtils.mkdir_p(ENV['FILES_ROOT'])
    ensure_root_directory
    ensure_movies_directory
  end

  after do
    FileUtils.rm_rf(ENV['FILES_ROOT']) if Dir.exist?(ENV['FILES_ROOT'])
  end

  describe 'GET /data_files/admin' do
    it 'renders broken and unrelated movie files for admins' do
      regular_directory = create(:directory, parent: ensure_root_directory)
      create(:data_file, directory: regular_directory, title: 'Broken file',
                         path: File.join(regular_directory.full_path, 'broken.txt'))

      unrelated_path = File.join(ensure_movies_directory.full_path, 'unrelated.mp4')
      FileUtils.mkdir_p(File.dirname(unrelated_path))
      File.write(unrelated_path, 'movie')
      allow_any_instance_of(DataFile).to receive(:should_create_movie?).and_return(false)
      unrelated_movie_file = create(:data_file, directory: ensure_movies_directory, title: 'Unrelated movie file',
                                                path: unrelated_path)

      login_as(admin)

      get '/data_files/admin'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Broken file')
      expect(response.body).to include('Unrelated movie file')
      expect(response.body.scan('Unrelated movie file').size).to eq(1)
      expect(unrelated_movie_file.movie).to be_nil
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get '/data_files/admin'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /data_files/new' do
    let!(:directory) { create(:directory, parent: ensure_root_directory) }

    it 'renders the new form for admins' do
      login_as(admin)

      get '/data_files/new', params: { id: directory.id }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get '/data_files/new', params: { id: directory.id }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /data_files/:id/edit' do
    it 'renders related-file options including the related count suffix' do
      login_as(admin)
      directory = create(:directory, parent: ensure_root_directory)
      file = create(:data_file, directory: directory, title: 'Base file')
      candidate = create(:data_file, directory: directory, title: 'Candidate file')
      create(:data_file, directory: directory, title: 'Already linked', related: candidate)
      create(:data_file, directory: directory, title: 'Plain file')

      get "/data_files/#{file.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Candidate file (+1 related files)')
      expect(response.body).to include('Plain file')
    end

    it 'returns 403 for non-admin users' do
      directory = create(:directory, parent: ensure_root_directory)
      file = create(:data_file, directory: directory)
      login_as(user)

      get "/data_files/#{file.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /data_files' do
    let!(:directory) { create(:directory, parent: ensure_root_directory) }
    let!(:article) { create(:article, user: admin) }

    before do
      login_as(admin)
      allow_any_instance_of(DataFile).to receive(:skip_file_validation_or_update?).and_return(true)
    end

    it 'redirects to the related article when one is attached' do
      post '/data_files',
           params: { data_file: { directory_id: directory.id, article_id: article.id, title: 'Article file' } }

      expect(response).to redirect_to(article_path(article))
      expect(flash[:notice]).to eq(I18n.t(:files_create))
    end

    it 'redirects to the created movie when the file is saved in the movies directory' do
      post '/data_files', params: { data_file: { directory_id: ensure_movies_directory.id, title: 'Movie file' } }

      created_file = DataFile.order(:id).last
      expect(created_file.movie).to be_present
      expect(response).to redirect_to(movie_path(created_file.movie))
    end

    it 'redirects to the file when no article or movie is created' do
      post '/data_files', params: { data_file: { directory_id: directory.id, title: 'Regular file' } }

      created_file = DataFile.order(:id).last
      expect(response).to redirect_to(data_file_path(created_file))
    end

    it 're-renders new when validation fails' do
      post '/data_files', params: { data_file: { directory_id: directory.id, title: 'a' * 256 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      expect do
        post '/data_files', params: { data_file: { directory_id: directory.id, title: 'Blocked file' } }
      end.not_to change(DataFile, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /data_files/:id' do
    let!(:directory) { create(:directory, parent: ensure_root_directory) }
    let!(:file) { create(:data_file, directory: directory, title: 'Original title') }

    before do
      login_as(admin)
    end

    it 'redirects to a safe return_to path when update succeeds' do
      patch "/data_files/#{file.id}", params: {
        data_file: { title: 'Updated title' },
        return_to: '/movies'
      }

      expect(response).to redirect_to('/movies')
      expect(file.reload.title).to eq('Updated title')
    end

    it 'falls back to the file page for an unsafe return_to path' do
      patch "/data_files/#{file.id}", params: {
        data_file: { title: 'Updated title' },
        return_to: '//evil.test'
      }

      expect(response).to redirect_to(data_file_path(file))
    end

    it 're-renders edit when validation fails' do
      patch "/data_files/#{file.id}", params: { data_file: { title: 'a' * 256 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:edit)
      expect(file.reload.title).to eq('Original title')
    end

    it 'returns 403 for non-admin users' do
      outsider = create(:user)
      login_as(outsider)

      patch "/data_files/#{file.id}", params: { data_file: { title: 'Blocked title' } }

      expect(response).to have_http_status(:forbidden)
      expect(file.reload.title).to eq('Original title')
    end
  end

  describe 'DELETE /data_files/:id' do
    it 'destroys the file and redirects to its directory' do
      directory = create(:directory, parent: ensure_root_directory)
      file = create(:data_file, directory: directory)
      login_as(admin)

      expect do
        delete "/data_files/#{file.id}"
      end.to change(DataFile, :count).by(-1)

      expect(response).to redirect_to(directory_path(directory))
    end
  end

  describe 'GET /data_files/trash' do
    it 'destroys only files missing from disk' do
      directory = create(:directory, parent: ensure_root_directory)
      missing = create(:data_file, directory: directory, title: 'Missing file',
                                   path: File.join(directory.full_path, 'missing.txt'))
      existing_path = File.join(directory.full_path, 'existing.txt')
      FileUtils.mkdir_p(File.dirname(existing_path))
      File.write(existing_path, 'ok')
      existing = create(:data_file, directory: directory, title: 'Existing file', path: existing_path)
      login_as(admin)

      expect do
        get '/data_files/trash'
      end.to change(DataFile, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Missing file')
      expect { missing.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(existing.reload).to be_present
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get '/data_files/trash'

      expect(response).to have_http_status(:forbidden)
    end
  end
end
