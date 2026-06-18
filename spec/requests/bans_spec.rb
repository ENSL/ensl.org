require 'rails_helper'

RSpec.describe 'BansController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:moderator) { create(:user, :gather_moderator) }
  let(:user) { create(:user) }

  describe 'GET /bans' do
    it 'renders the index' do
      ban = create(:ban, reason: 'Index reason')

      get '/bans'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ban.reason)
    end
  end

  describe 'GET /bans/new' do
    it 'allows moderators' do
      login_as(moderator)

      get '/bans/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for normal users' do
      login_as(user)

      get '/bans/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /bans/:id' do
    it 'renders the ban details' do
      ban = create(:ban, creator: moderator, reason: 'Shown ban')

      get "/bans/#{ban.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Shown ban')
    end
  end

  describe 'GET /bans/:id/edit' do
    it 'allows the creator to edit the ban' do
      ban = create(:ban, creator: moderator)
      login_as(moderator)

      get "/bans/#{ban.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for unrelated users' do
      ban = create(:ban, creator: moderator)
      login_as(user)

      get "/bans/#{ban.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /bans' do
    let(:target_user) { create(:user) }

    it 'creates bans for moderators and stores the creator' do
      login_as(moderator)

      expect do
        post '/bans', params: {
          ban: {
            ban_type: Ban::TYPE_SITE,
            expiry: 2.days.from_now.utc,
            reason: 'Temporary site ban',
            user_name: target_user.username
          }
        }
      end.to change(Ban, :count).by(1)

      expect(response).to redirect_to(ban_path(Ban.order(:id).last))
      expect(Ban.order(:id).last.creator).to eq(moderator)
    end

    it 'renders new for invalid data' do
      login_as(moderator)

      expect do
        post '/bans', params: {
          ban: {
            ban_type: Ban::TYPE_SITE,
            expiry: 2.days.from_now.utc,
            reason: 'Broken ban',
            user_name: 'missing-user'
          }
        }
      end.not_to change(Ban, :count)

      expect(response).to have_http_status(422)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for users without ban access' do
      login_as(user)

      expect do
        post '/bans', params: {
          ban: {
            ban_type: Ban::TYPE_SITE,
            expiry: 2.days.from_now.utc,
            reason: 'Blocked ban',
            user_name: target_user.username
          }
        }
      end.not_to change(Ban, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /bans/:id' do
    let!(:ban) { create(:ban, creator: moderator, reason: 'Original reason') }

    it 'allows the creator to update their own ban' do
      login_as(moderator)

      patch "/bans/#{ban.id}", params: {
        ban: {
          ban_type: ban.ban_type,
          expiry: ban.expiry + 1.day,
          reason: 'Updated reason',
          user_name: ban.user.username
        }
      }

      expect(response).to redirect_to(ban_path(ban))
      expect(ban.reload.reason).to eq('Updated reason')
    end

    it 'renders edit for invalid updates' do
      login_as(moderator)

      patch "/bans/#{ban.id}", params: {
        ban: {
          ban_type: ban.ban_type,
          expiry: ban.expiry,
          reason: 'Updated reason',
          steamid: 'bad-steamid'
        }
      }

      expect(response).to have_http_status(422)
      expect(response).to render_template(:edit)
      expect(ban.reload.reason).to eq('Original reason')
    end

    it 'returns 403 for unrelated users' do
      login_as(user)

      patch "/bans/#{ban.id}", params: {
        ban: {
          ban_type: ban.ban_type,
          expiry: ban.expiry,
          reason: 'Blocked update',
          user_name: ban.user.username
        }
      }

      expect(response).to have_http_status(:forbidden)
      expect(ban.reload.reason).to eq('Original reason')
    end
  end

  describe 'DELETE /bans/:id' do
    it 'allows admins to destroy bans' do
      ban = create(:ban, creator: moderator)
      login_as(admin)

      expect do
        delete "/bans/#{ban.id}"
      end.to change(Ban, :count).by(-1)

      expect(response).to redirect_to(bans_path)
    end

    it 'returns 403 for normal users' do
      ban = create(:ban, creator: moderator)
      login_as(user)

      expect do
        delete "/bans/#{ban.id}"
      end.not_to change(Ban, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
