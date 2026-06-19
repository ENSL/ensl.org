require 'rails_helper'

RSpec.describe 'LocksController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:topic) { create(:topic) }

  describe 'POST /locks' do
    it 'creates locks for admins' do
      login_as(admin)

      expect do
        post '/locks',
             params: { lock: { lockable_type: 'Topic', lockable_id: topic.id } },
             headers: { 'HTTP_REFERER' => topic_url(topic) }
      end.to change(Lock, :count).by(1)

      expect(response).to redirect_to(topic_path(topic))
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      expect do
        post '/locks',
             params: { lock: { lockable_type: 'Topic', lockable_id: topic.id } },
             headers: { 'HTTP_REFERER' => topic_url(topic) }
      end.not_to change(Lock, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /locks/:id' do
    it 'destroys locks for admins' do
      lock = Lock.create!(lockable: topic)
      login_as(admin)

      expect do
        delete "/locks/#{lock.id}", headers: { 'HTTP_REFERER' => topic_url(topic) }
      end.to change(Lock, :count).by(-1)

      expect(response).to redirect_to(topic_path(topic))
    end

    it 'returns 403 for non-admins' do
      lock = Lock.create!(lockable: topic)
      login_as(user)

      expect do
        delete "/locks/#{lock.id}", headers: { 'HTTP_REFERER' => topic_url(topic) }
      end.not_to change(Lock, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
