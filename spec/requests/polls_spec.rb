# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PollsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(account)
    post '/sessions/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  def create_poll(question: 'Best map?', options: %w[Dust2 Inferno])
    poll = Poll.new(question: question)
    options.each { |option| poll.options.build(option: option) }
    poll.save!
    poll
  end

  def poll_params(question:, options:)
    {
      poll: {
        question: question,
        options_attributes: options.each_with_index.to_h do |option, index|
          [index.to_s, { option: option }]
        end
      }
    }
  end

  describe 'GET /polls' do
    let!(:older_poll) { create_poll(question: 'Older poll?') }
    let!(:newer_poll) { create_poll(question: 'Newer poll?') }

    it 'lists polls for guests' do
      Poll.where(id: [older_poll.id, newer_poll.id]).update_all(created_at: Time.current)

      get polls_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Older poll?')
      expect(response.body).to include('Newer poll?')
      expect(response.body).to match(/Newer poll\?.*Older poll\?/m)
    end
  end

  describe 'GET /polls/:id' do
    let!(:poll) { create_poll(question: 'Show me?') }

    it 'renders the poll' do
      get poll_path(poll)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Show me?')
      expect(response.body).to include('Dust2')
    end
  end

  describe 'GET /polls/new' do
    it 'allows admins to load the form' do
      login_as(admin)

      get new_poll_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Poll')
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get new_poll_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /polls' do
    it 'creates a poll for admins' do
      login_as(admin)

      expect do
        post polls_path, params: poll_params(question: 'Created poll?', options: %w[Train Nuke])
      end.to change(Poll, :count).by(1)

      created_poll = Poll.last
      expect(response).to redirect_to(poll_path(created_poll))
      expect(created_poll.user).to eq(admin)
      expect(created_poll.options.map(&:option)).to contain_exactly('Train', 'Nuke')
      expect(flash[:notice]).to eq(I18n.t('flash.actions.create.notice', resource_name: Poll.model_name.human))
    end

    it 're-renders the form for invalid admin input' do
      login_as(admin)

      expect do
        post polls_path, params: poll_params(question: '', options: ['Only one'])
      end.not_to change(Poll, :count)

      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      expect do
        post polls_path, params: poll_params(question: 'Blocked poll?', options: %w[A B])
      end.not_to change(Poll, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /polls/:id/edit' do
    let!(:poll) { create_poll(question: 'Editable poll?') }

    it 'allows admins to load the edit form' do
      login_as(admin)

      get edit_poll_path(poll)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit Poll')
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get edit_poll_path(poll)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /polls/:id' do
    let!(:poll) { create_poll(question: 'Old question?') }

    it 'updates a poll for admins' do
      login_as(admin)

      patch poll_path(poll), params: {
        poll: {
          question: 'New question?',
          options_attributes: poll.options.each_with_index.to_h do |option, index|
            [index.to_s, { id: option.id, option: "Updated #{index}" }]
          end
        }
      }

      expect(response).to redirect_to(poll_path(poll))
      expect(poll.reload.question).to eq('New question?')
      expect(poll.options.order(:id).pluck(:option)).to eq(['Updated 0', 'Updated 1'])
      expect(flash[:notice]).to eq(I18n.t('flash.actions.update.notice', resource_name: Poll.model_name.human))
    end

    it 're-renders the edit form for invalid admin input' do
      login_as(admin)

      patch poll_path(poll), params: {
        poll: {
          question: '',
          options_attributes: poll.options.each_with_index.to_h do |option, index|
            [index.to_s, { id: option.id, option: "Still here #{index}" }]
          end
        }
      }

      expect(response).to render_template(:edit)
      expect(poll.reload.question).to eq('Old question?')
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      patch poll_path(poll), params: poll_params(question: 'Blocked update?', options: %w[One Two])

      expect(response).to have_http_status(:forbidden)
      expect(poll.reload.question).to eq('Old question?')
    end
  end

  describe 'DELETE /polls/:id' do
    let!(:poll) { create_poll(question: 'Delete me?') }

    it 'destroys a poll for admins' do
      login_as(admin)

      expect do
        delete poll_path(poll)
      end.to change(Poll, :count).by(-1)

      expect(response).to redirect_to(polls_path)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      expect do
        delete poll_path(poll)
      end.not_to change(Poll, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /polls/:id/showvotes' do
    let!(:poll) { create_poll(question: 'Who voted?') }
    let!(:voter) { create(:user) }

    before do
      Vote.create!(user: voter, votable: poll.options.first)
    end

    it 'allows admins to view poll votes' do
      login_as(admin)

      get showvotes_poll_path(poll)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Who voted?')
      expect(response.body).to include(voter.username)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get showvotes_poll_path(poll)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
