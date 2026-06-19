# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChallengesController, type: :controller do
  before do
    routes.draw do
      resources :challenges, only: %i[update destroy create] do
        collection do
          get :refresh
        end
      end
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#update' do
    it 'renders show without reloading when the challenge is not persisted' do
      challenge = double('Challenge', can_update?: true, update: false, persisted?: false)
      allow(Challenge).to receive(:find).with('1').and_return(challenge)
      allow(Challenge).to receive(:params).and_return(ActionController::Parameters.new(response: 'No change'))

      patch :update, params: { id: '1', commit: 'Unexpected', challenge: { response: 'No change' } }

      expect(response).to render_template(:show)
    end
  end
end
