# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IssuesController, type: :controller do
  before do
    routes.draw do
      resources :issues, only: %i[new create edit]
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#new' do
    it 'returns 403 when the issue cannot be created' do
      allow_any_instance_of(Issue).to receive(:can_create?).and_return(false)

      get :new

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '#create' do
    it 'returns 403 when the issue cannot be created' do
      allow_any_instance_of(Issue).to receive(:can_create?).and_return(false)

      post :create, params: { issue: { title: 'Denied', text: 'Denied body', category_id: Issue::CATEGORY_GATHER } }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
