require 'rails_helper'

RSpec.describe 'GatherersController', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:other_user) { create(:user) }
  let(:gather) { create(:gather, :running) }

  before do
    allow(Gathers::Broadcaster).to receive(:call)
  end

  describe 'POST /gatherers' do
    it 'redirects after a successful html join' do
      login_as(user)
      gatherer = build(:gatherer, gather: gather, user: user)
      result = instance_double('Gathers::Join::Result', success?: true, gatherer: gatherer, gather: gather, error: nil)
      allow(Gathers::Join).to receive(:call).and_return(result)

      post '/gatherers', params: { gatherer: { gather_id: gather.id, user_id: user.id, confirm: '1' } }

      expect(response).to redirect_to(gather_path(gather))
      expect(flash[:notice]).to be_present
    end

    it 'redirects after a failed html join' do
      login_as(user)
      gatherer = build(:gatherer, gather: gather, user: user)
      gatherer.errors.add(:base, 'Join failed')
      result = instance_double('Gathers::Join::Result', success?: false, gatherer: gatherer, gather: gather,
                                                        error: 'Join failed')
      allow(Gathers::Join).to receive(:call).and_return(result)

      post '/gatherers', params: { gatherer: { gather_id: gather.id, user_id: user.id, confirm: '1' } }

      expect(response).to redirect_to(gather_path(gather))
      expect(flash[:error]).to include('Join failed')
    end

    it 'renders a turbo-stream response on success' do
      login_as(user)
      gatherer = create(:gatherer, gather: gather, user: user)
      result = instance_double('Gathers::Join::Result', success?: true, gatherer: gatherer, gather: gather, error: nil)
      allow(Gathers::Join).to receive(:call).and_return(result)

      post '/gatherers',
           params: { gatherer: { gather_id: gather.id, user_id: user.id, confirm: '1' } },
           headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'renders a turbo-stream response on failure' do
      login_as(user)
      gatherer = build(:gatherer, gather: gather, user: user)
      gatherer.errors.add(:base, 'Join failed')
      result = instance_double('Gathers::Join::Result', success?: false, gatherer: gatherer, gather: gather,
                                                        error: 'Join failed')
      allow(Gathers::Join).to receive(:call).and_return(result)

      post '/gatherers',
           params: { gatherer: { gather_id: gather.id, user_id: user.id, confirm: '1' } },
           headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end

  describe 'PATCH /gatherers/:id' do
    let!(:gatherer) { create(:gatherer, gather: gather, user: user) }

    it 'updates and broadcasts when the change succeeds' do
      login_as(admin)
      allow_any_instance_of(Gatherer).to receive(:can_update?).and_return(true)

      patch "/gatherers/#{gatherer.id}",
            params: { gatherer: { id: gatherer.id, team: 1 } },
            headers: { 'HTTP_REFERER' => gather_path(gather) }

      expect(response).to redirect_to(gather_path(gather))
      expect(Gathers::Broadcaster).to have_received(:call).with(gatherer.gather)
    end

    it 'redirects back with an error when update fails' do
      login_as(admin)
      allow_any_instance_of(Gatherer).to receive(:can_update?).and_return(true)
      allow_any_instance_of(Gatherer).to receive(:update).and_return(false)
      allow_any_instance_of(Gatherer).to receive(:errors).and_return(double(full_messages: ['Invalid update']))

      patch "/gatherers/#{gatherer.id}",
            params: { gatherer: { id: gatherer.id, team: 1 } },
            headers: { 'HTTP_REFERER' => gather_path(gather) }

      expect(response).to redirect_to(gather_path(gather))
      expect(flash[:error]).to include('Invalid update')
    end

    it 'returns 403 when the user cannot update the gatherer' do
      login_as(other_user)

      patch "/gatherers/#{gatherer.id}", params: { gatherer: { id: gatherer.id, team: 1 } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /gatherers/:id/status' do
    let!(:gatherer) { create(:gatherer, gather: gather, user: user, status: Gatherer::STATE_ACTIVE) }

    it 'updates the status for a valid transition' do
      login_as(user)

      post "/gatherers/#{gatherer.id}/status", params: { status: 'away' }

      expect(response).to have_http_status(:ok)
      expect(gatherer.reload.status).to eq(Gatherer::STATE_AWAY)
      expect(Gathers::Broadcaster).to have_received(:call).with(gather)
    end

    it 'ignores invalid statuses' do
      login_as(user)

      post "/gatherers/#{gatherer.id}/status", params: { status: 'invalid-state' }

      expect(response).to have_http_status(:ok)
      expect(gatherer.reload.status).to eq(Gatherer::STATE_ACTIVE)
    end

    it 'returns 403 for unauthorized users' do
      login_as(other_user)

      post "/gatherers/#{gatherer.id}/status", params: { status: 'away' }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /gatherers/:id' do
    let!(:gatherer) { create(:gatherer, gather: gather, user: user) }

    it 'uses the kick service for admins removing someone else' do
      login_as(admin)
      result = instance_double('Gathers::Kick::Result', success?: true, gather: gather, error: nil)
      allow(Gathers::Kick).to receive(:call).and_return(result)
      allow(Gathers::Leave).to receive(:call)

      delete "/gatherers/#{gatherer.id}"

      expect(response).to redirect_to(gather_path(gather))
      expect(Gathers::Kick).to have_received(:call).with(actor: admin, gatherer: gatherer)
      expect(Gathers::Leave).not_to have_received(:call)
      expect(flash[:notice]).to be_present
    end

    it 'uses the leave service and reports failures for self-removal' do
      login_as(user)
      result = instance_double('Gathers::Leave::Result', success?: false, gather: gather, error: 'Cannot leave')
      allow(Gathers::Leave).to receive(:call).and_return(result)
      allow(Gathers::Kick).to receive(:call)

      delete "/gatherers/#{gatherer.id}"

      expect(response).to redirect_to(gather_path(gather))
      expect(Gathers::Leave).to have_received(:call).with(actor: user, gatherer: gatherer)
      expect(Gathers::Kick).not_to have_received(:call)
      expect(flash[:error]).to include('Cannot leave')
    end
  end
end
