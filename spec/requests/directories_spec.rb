require 'rails_helper'

RSpec.describe 'DirectoriesController', type: :request do
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

  before do
    ENV['FILES_ROOT'] = File.join(Dir.tmpdir, 'ensl_directories_request_spec')
    FileUtils.rm_rf(ENV['FILES_ROOT'])
    FileUtils.mkdir_p(ENV['FILES_ROOT'])
    ensure_root_directory
  end

  after do
    FileUtils.rm_rf(ENV['FILES_ROOT']) if Dir.exist?(ENV['FILES_ROOT'])
  end

  describe 'GET /directories/:id' do
    it 'renders the file list for a hidden directory' do
      directory = create(:directory, parent: ensure_root_directory, hidden: true)
      create(:data_file, directory: directory, title: 'Hidden File', description: 'Directory description paragraph')

      get "/directories/#{directory.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Hidden File')
      expect(response.body).to include('Directory description paragraph')
    end

    it 'loads the root listing for a visible directory' do
      directory = create(:directory, parent: ensure_root_directory, hidden: false)

      get "/directories/#{directory.id}"

      expect(response).to have_http_status(:ok)
      expect(assigns(:directories)).to all(have_attributes(parent_id: Directory::ROOT))
    end
  end

  describe 'GET /directories/new' do
    it 'renders the new form for admins' do
      login_as(admin)

      get '/directories/new', params: { id: ensure_root_directory.id }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get '/directories/new', params: { id: ensure_root_directory.id }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /directories/:id/edit' do
    it 'renders the edit form for admins' do
      directory = create(:directory, parent: ensure_root_directory)
      login_as(admin)

      get "/directories/#{directory.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for non-admin users' do
      directory = create(:directory, parent: ensure_root_directory)
      login_as(user)

      get "/directories/#{directory.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /directories' do
    before do
      login_as(admin)
    end

    it 'creates a directory and redirects to it when valid' do
      expect do
        post '/directories', params: {
          directory: {
            name: 'clips',
            title: 'Clips',
            parent_id: ensure_root_directory.id,
            description: 'Fresh directory'
          }
        }
      end.to change(Directory, :count).by(1)

      expect(response).to redirect_to(directory_path(Directory.order(:id).last))
    end

    it 're-renders new when validation fails' do
      expect do
        post '/directories', params: {
          directory: {
            name: 'bad name',
            title: 'Broken',
            parent_id: ensure_root_directory.id
          }
        }
      end.not_to change(Directory, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      expect do
        post '/directories', params: {
          directory: {
            name: 'blocked',
            title: 'Blocked',
            parent_id: ensure_root_directory.id
          }
        }
      end.not_to change(Directory, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /directories/:id' do
    let!(:directory) { create(:directory, parent: ensure_root_directory, description: 'Old description') }

    it 'updates directory description when valid' do
      login_as(admin)

      patch "/directories/#{directory.id}", params: { directory: { description: 'Updated description' } }

      expect(response).to redirect_to(directory_path(directory))
      expect(directory.reload.description).to eq('Updated description')
    end

    it 're-renders edit when description is too long' do
      login_as(admin)

      patch "/directories/#{directory.id}", params: { directory: { description: 'a' * 256 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:edit)
      expect(directory.reload.description).to eq('Old description')
    end

    it 'returns 403 for a non-admin user' do
      login_as(user)

      patch "/directories/#{directory.id}", params: { directory: { description: 'Nope' } }

      expect(response).to have_http_status(:forbidden)
      expect(directory.reload.description).to eq('Old description')
    end
  end

  describe 'POST /directories/:id/reconcile' do
    let!(:directory) { create(:directory, parent: ensure_root_directory) }
    let(:service_result) { StringIO.new("line 1\nline 2") }
    let(:service) { instance_double(DirectoryReconciliationService, call: service_result) }

    before do
      allow(DirectoryReconciliationService).to receive(:new).with(directory).and_return(service)
    end

    it 'renders the reconcile page for html requests' do
      login_as(admin)

      post "/directories/#{directory.id}/reconcile"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:reconcile)
      expect(response.body).to include('line 1')
    end

    it 'renders html content for turbo stream requests' do
      login_as(admin)

      post "/directories/#{directory.id}/reconcile", headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('line 2')
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      post "/directories/#{directory.id}/reconcile"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /directories/:id' do
    it 'destroys the directory and redirects to root' do
      directory = create(:directory, parent: ensure_root_directory)
      login_as(admin)

      expect do
        delete "/directories/#{directory.id}"
      end.to change(Directory, :count).by(-1)

      expect(response).to redirect_to(directory_path(Directory::ROOT))
    end

    it 'returns 403 for non-admin users' do
      directory = create(:directory, parent: ensure_root_directory)
      login_as(user)

      expect do
        delete "/directories/#{directory.id}"
      end.not_to change(Directory, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
