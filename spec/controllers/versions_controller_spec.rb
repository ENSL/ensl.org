# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VersionsController, type: :controller do
  render_views

  let!(:article) { create(:article) }

  describe 'GET #index' do
    it 'returns 404 when article version table is unavailable' do
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('article_versions').and_return(false)

      get :index, params: { article_id: article.id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
