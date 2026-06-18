require 'rails_helper'

RSpec.describe 'MessagesController', type: :request do
  let(:sender) { create(:user) }
  let(:recipient) { create(:user) }
  let(:outsider) { create(:user) }
  let(:group) { create(:group) }
  let(:team_owner) { create(:user) }
  let!(:team) { create(:team, :with_leader, founder: team_owner) }

  describe 'GET /messages' do
    it 'renders for signed-in users' do
      login_as(sender)

      get '/messages'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
    end

    it 'returns 403 for guests' do
      get '/messages'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /messages/:id' do
    it 'shows a message to its recipient' do
      message = create(:message, sender: sender, recipient: recipient)
      login_as(recipient)

      get "/messages/#{message.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end

    it 'returns 403 for unrelated users' do
      message = create(:message, sender: sender, recipient: recipient)
      login_as(outsider)

      get "/messages/#{message.id}"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /messages/new' do
    before do
      login_as(sender)
    end

    it 'prepares a user recipient' do
      get '/messages/new', params: { id: 'User', id2: recipient.id, title: 'Hello' }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'prepares a team recipient' do
      get '/messages/new', params: { id: 'Team', id2: team.id, title: 'Hello' }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'prepares a group recipient' do
      get '/messages/new', params: { id: 'Group', id2: group.id, title: 'Hello' }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe 'POST /messages' do
    it 'creates a direct message for a user recipient' do
      login_as(sender)

      expect do
        post '/messages', params: {
          message: {
            recipient_type: 'User',
            recipient_id: recipient.id,
            title: 'Request spec message',
            text: 'Sent from a request spec',
            sender_raw: ''
          }
        }
      end.to change(Message, :count).by(1)

      expect(response).to redirect_to(message_path(Message.last))
      expect(Message.last.sender).to eq(sender)
    end

    it 'creates a team-sender message when sender_raw is set' do
      login_as(team_owner)

      expect do
        post '/messages', params: {
          message: {
            recipient_type: 'User',
            recipient_id: recipient.id,
            title: 'Team message',
            text: 'Team-originated note',
            sender_raw: team.id.to_s
          }
        }
      end.to change(Message, :count).by(1)

      expect(response).to redirect_to(message_path(Message.last))
      expect(Message.last.sender).to eq(team)
    end

    it 're-renders new when validation fails' do
      login_as(sender)
      allow_any_instance_of(Message).to receive(:save).and_return(false)

      expect do
        post '/messages', params: {
          message: {
            recipient_type: 'User',
            recipient_id: recipient.id,
            title: 'Invalid render path',
            text: 'Still renders new',
            sender_raw: ''
          }
        }
      end.not_to change(Message, :count)

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      expect do
        post '/messages', params: {
          message: {
            recipient_type: 'User',
            recipient_id: recipient.id,
            title: 'Blocked',
            text: 'Blocked',
            sender_raw: ''
          }
        }
      end.not_to change(Message, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
