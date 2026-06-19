# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GroupersController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'POST /groupers' do
    it 'creates a grouper for admins' do
      login_as(admin)

      expect do
        post '/groupers', params: { grouper: { group_id: group.id, username: user.username, task: 'Moderator' } }
      end.to change(Grouper, :count).by(1)

      grouper = Grouper.order(:id).last
      expect(response).to redirect_to(edit_group_path(group, anchor: 'members'))
      expect(grouper.user).to eq(user)
      expect(grouper.task).to eq('Moderator')
      expect(flash[:notice]).to be_present
    end

    it 'returns 422 when the username does not resolve to a user' do
      login_as(admin)

      expect do
        post '/groupers', params: { grouper: { group_id: group.id, username: 'missing-user' } }
      end.not_to change(Grouper, :count)

      expect(response).to have_http_status(422)
      expect(response).to render_template('groups/edit')
    end

    it 'returns 422 when the membership already exists' do
      create(:grouper, group: group, user: user)
      login_as(admin)

      expect do
        post '/groupers', params: { grouper: { group_id: group.id, username: user.username } }
      end.not_to change(Grouper, :count)

      expect(response).to have_http_status(422)
      expect(response).to render_template('groups/edit')
    end

    it 'returns 403 for non-admins' do
      target_user = create(:user)
      login_as(user)

      expect do
        post '/groupers', params: { grouper: { group_id: group.id, username: target_user.username } }
      end.not_to change(Grouper, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /groupers/:id' do
    let(:grouper) { create(:grouper, group: group, user: user, task: 'Initial') }

    it 'updates the task for admins' do
      login_as(admin)

      patch "/groupers/#{grouper.id}", params: { grouper: { task: 'Updated Role' } }

      expect(response).to redirect_to(edit_group_path(group, anchor: 'members'))
      expect(grouper.reload.task).to eq('Updated Role')
    end

    it 'returns 422 for invalid updates' do
      login_as(admin)

      patch "/groupers/#{grouper.id}", params: { grouper: { task: 'x' * 26 } }

      expect(response).to have_http_status(422)
      expect(response).to render_template('groups/edit')
      expect(grouper.reload.task).to eq('Initial')
    end
  end

  describe 'DELETE /groupers/:id' do
    let!(:grouper) { create(:grouper, group: group, user: user) }

    it 'destroys the membership for admins' do
      login_as(admin)

      expect do
        delete "/groupers/#{grouper.id}"
      end.to change(Grouper, :count).by(-1)

      expect(response).to redirect_to(edit_group_path(group, anchor: 'members'))
      expect(flash[:notice]).to be_present
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      expect do
        delete "/groupers/#{grouper.id}"
      end.not_to change(Grouper, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
