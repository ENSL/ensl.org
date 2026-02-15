require 'rails_helper'

RSpec.describe MatchesController, type: :controller do
  let(:admin) { create(:user, :admin) }

  before do
    session[:user] = admin.id
  end

  describe 'POST create' do
    it 'returns 422 when validation fails' do
      post :create, params: { match: { contest_id: nil } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH update' do
    let!(:contest) { create(:contest) }
    let!(:contester1) { create(:contester, contest: contest) }
    let!(:contester2) { create(:contester, contest: contest) }
    let!(:match) { create(:match, contest: contest, contester1: contester1, contester2: contester2) }

    it 'returns 422 when update validation fails' do
      patch :update, params: { id: match.id, match: { contester1_id: nil } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
