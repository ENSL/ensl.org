require 'rails_helper'

RSpec.describe DirectoriesController, type: :controller do
  render_views

  let!(:admin) { create(:user, :admin) }

  before do
    ENV['FILES_ROOT'] = '/tmp/test_directories_controller'
    FileUtils.mkdir_p(ENV['FILES_ROOT'])
  end

  after do
    FileUtils.rm_rf(ENV['FILES_ROOT']) if Dir.exist?(ENV['FILES_ROOT'])
  end

  describe 'GET #show' do
    it 'renders directory description as paragraph content' do
      login_admin
      root = Directory.find_or_create_by(id: Directory::ROOT) do |dir|
        dir.name = 'root'
        dir.title = 'Root'
        dir.hidden = false
        dir.path = ENV['FILES_ROOT']
      end
      directory = create(:directory, parent: root, description: 'Directory description paragraph')

      get :show, params: { id: directory.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Directory description paragraph')
    end
  end

  describe 'PUT #update' do
    let!(:root) do
      Directory.find_or_create_by(id: Directory::ROOT) do |dir|
        dir.name = 'root'
        dir.title = 'Root'
        dir.hidden = false
        dir.path = ENV['FILES_ROOT']
      end
    end
    let!(:directory) { create(:directory, parent: root, description: 'Old description') }

    it 'updates directory description when valid' do
      login_admin

      put :update, params: { id: directory.id, directory: { description: 'Updated description' } }

      expect(response).to redirect_to(directory_path(directory))
      expect(directory.reload.description).to eq('Updated description')
    end

    it 're-renders edit when description is too long' do
      login_admin
      long_description = 'a' * 256

      put :update, params: { id: directory.id, directory: { description: long_description } }

      expect(response).to render_template('edit')
      expect(directory.reload.description).to eq('Old description')
    end
  end
end
