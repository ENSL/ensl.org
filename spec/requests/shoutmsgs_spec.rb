require 'rails_helper'

RSpec.describe 'Shoutmsgs', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  def login_as(u)
    post '/users/login', params: { login: { username: u.username, password: u.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /shoutmsgs' do
    it 'renders index with shoutbox history table' do
      create(:shoutmsg, text: 'main-msg-1')
      create(:shoutmsg, text: 'main-msg-2')

      get '/shoutmsgs'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
      expect(response.body).to include('Last 500 Shoutbox Messages')
      expect(response.body).to include('main-msg-1')
      expect(response.body).to include('main-msg-2')
    end
  end

  describe 'GET /shoutmsgs/:id' do
    it 'hits main shoutbox show branch', :expect_log_error do
      get '/shoutmsgs/shoutbox'
      expect(response).to have_http_status(:not_acceptable)
    end

    it 'hits object-specific show branch with id2 param', :expect_log_error do
      gather = create(:gather, :running)
      create(:shoutmsg, shoutable: gather, text: 'gather-msg')

      get '/shoutmsgs/Gather', params: { id2: gather.id }

      expect(response).to have_http_status(:not_acceptable)
    end
  end

  describe 'POST /shoutmsgs' do
    context 'turbo stream' do
      it 'creates main shout and resets the main shout form' do
        login_as(user)

        expect do
          post '/shoutmsgs',
               params: { shoutmsg: { text: 'hello-main' } },
               headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }
        end.to change(Shoutmsg, :count).by(1)

        created = Shoutmsg.order(:id).last
        expect(response).to have_http_status(:ok)
        expect(created.shoutable_type).to be_nil
        expect(created.shoutable_id).to be_nil
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('target="new_shoutbox"')
      end

      it 'creates gather shout and resets the gather shout form' do
        login_as(user)
        gather = create(:gather, :running)

        expect do
          post '/shoutmsgs',
               params: { shoutmsg: { shoutable_type: 'Gather', shoutable_id: gather.id, text: 'hello-gather' } },
               headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }
        end.to change(Shoutmsg, :count).by(1)

        created = Shoutmsg.order(:id).last
        expect(response).to have_http_status(:ok)
        expect(created.shoutable_type).to eq('Gather')
        expect(created.shoutable_id).to eq(gather.id)
        expect(response.body).to include("target=\"new_shout_Gather_#{gather.id}\"")
      end

      it 'returns validation errors and notification replacement for invalid text' do
        login_as(user)

        expect do
          post '/shoutmsgs',
               params: { shoutmsg: { text: 'a' * 101 } },
               headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }
        end.not_to change(Shoutmsg, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('target="new_shoutbox"')
        expect(response.body).to include('target="notification"')
      end

      it 'falls back to the generic invalid message when no validation text is available' do
        login_as(user)
        allow_any_instance_of(Shoutmsg).to receive(:save).and_return(false)
        allow_any_instance_of(Shoutmsg).to receive(:errors).and_return(double(full_messages: []))

        post '/shoutmsgs',
             params: { shoutmsg: { text: 'hello-main' } },
             headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('target="notification"')
        expect(response.body).to include(I18n.t(:invalid_message))
      end

      it 'forbids unauthenticated users from creating shouts' do
        expect do
          post '/shoutmsgs', params: { shoutmsg: { text: 'nope' } }
        end.not_to change(Shoutmsg, :count)

        expect(response).to have_http_status(:forbidden)
      end

      it 'forbids muted users from creating shouts' do
        login_as(user)
        Ban.create!(ban_type: Ban::TYPE_MUTE, expiry: Time.now.utc + 10.days, user_name: user.username)

        expect do
          post '/shoutmsgs', params: { shoutmsg: { text: 'blocked' } }
        end.not_to change(Shoutmsg, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'html' do
      it 'redirects back after successful create' do
        login_as(user)

        expect do
          post '/shoutmsgs', params: { shoutmsg: { text: 'html-main' } }
        end.to change(Shoutmsg, :count).by(1)

        expect(response).to have_http_status(:redirect)
      end

      it 'redirects back with error on invalid create' do
        login_as(user)

        expect do
          post '/shoutmsgs', params: { shoutmsg: { text: 'b' * 101 } }
        end.not_to change(Shoutmsg, :count)

        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'DELETE /shoutmsgs/:id' do
    it 'allows admin to destroy shout' do
      login_as(admin)
      shoutmsg = create(:shoutmsg)

      expect do
        delete "/shoutmsgs/#{shoutmsg.id}"
      end.to change(Shoutmsg, :count).by(-1)

      expect(response).to have_http_status(:redirect)
    end

    it 'forbids non-admin from destroying shout' do
      login_as(user)
      shoutmsg = create(:shoutmsg)

      expect do
        delete "/shoutmsgs/#{shoutmsg.id}"
      end.not_to change(Shoutmsg, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
