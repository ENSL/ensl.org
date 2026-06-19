# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VotesController', type: :request do
  let(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  def create_poll(question: 'Vote now?', options: %w[Alpha Beta])
    poll = Poll.new(question: question)
    options.each { |option| poll.options.build(option: option) }
    poll.save!
    poll
  end

  describe 'POST /votes for poll options' do
    let!(:poll) { create_poll }
    let!(:option) { poll.options.first }

    it 'creates a vote and redirects back for signed-in users' do
      login_as(user)

      expect do
        post votes_path,
             params: { vote: { votable_type: 'Option', votable_id: option.id } },
             headers: { 'HTTP_REFERER' => poll_url(poll) }
      end.to change(Vote, :count).by(1)

      expect(response).to redirect_to(poll_path(poll))
      expect(Vote.last.user).to eq(user)
      expect(flash[:notice]).to eq(I18n.t(:votes_success))
    end

    it 'redirects back without a success flash when the vote does not save' do
      login_as(user)
      vote = instance_double(Vote, can_create?: true, save: false)
      allow(vote).to receive(:user=)
      allow(Vote).to receive(:new).and_return(vote)

      expect do
        post votes_path,
             params: { vote: { votable_type: 'Option', votable_id: option.id } },
             headers: { 'HTTP_REFERER' => poll_url(poll) }
      end.not_to change(Vote, :count)

      expect(response).to redirect_to(poll_path(poll))
      expect(flash[:notice]).to be_nil
    end

    it 'returns 403 for guests' do
      expect do
        post votes_path, params: { vote: { votable_type: 'Option', votable_id: option.id } }
      end.not_to change(Vote, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /votes for gather voting' do
    let!(:gather) { create(:gather) }

    before do
      login_as(user)
    end

    it 'redirects to the gather on successful gather votes' do
      result = instance_double('Gathers::Result', success?: true, gather: gather)
      allow(Gathers::CastVote).to receive(:call).and_return(result)

      post votes_path, params: { vote: { votable_type: 'GatherMap', votable_id: 123 } }

      expect(response).to redirect_to(gather_path(gather))
      expect(flash[:notice]).to eq(I18n.t(:votes_success))
    end

    it 'redirects back when a successful gather vote does not return a gather' do
      result = instance_double('Gathers::Result', success?: true, gather: nil)
      allow(Gathers::CastVote).to receive(:call).and_return(result)

      post votes_path,
           params: { vote: { votable_type: 'GatherServer', votable_id: 456 } },
           headers: { 'HTTP_REFERER' => polls_url }

      expect(response).to redirect_to(polls_path)
      expect(flash[:notice]).to eq(I18n.t(:votes_success))
    end

    it 'redirects back with an error flash when gather voting fails' do
      result = instance_double('Gathers::Result', success?: false, gather: nil, error: 'Vote rejected')
      allow(Gathers::CastVote).to receive(:call).and_return(result)

      post votes_path,
           params: { vote: { votable_type: 'Gatherer', votable_id: 789 } },
           headers: { 'HTTP_REFERER' => root_url }

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq('Vote rejected')
    end
  end
end
