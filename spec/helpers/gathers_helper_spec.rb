# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GathersHelper, type: :helper do
  describe '#gather_current_user' do
    it 'prefers the gatherer user when present' do
      gather_user = instance_double(User)
      allow(helper).to receive(:gatherer_from_context).and_return(instance_double(Gatherer, user: gather_user))
      helper.define_singleton_method(:cuser) { instance_double(User) }

      expect(helper.gather_current_user).to eq(gather_user)
    end

    it 'falls back to the current user' do
      current_user = instance_double(User)
      allow(helper).to receive(:gatherer_from_context).and_return(nil)
      helper.define_singleton_method(:cuser) { current_user }

      expect(helper.gather_current_user).to eq(current_user)
    end
  end

  describe '#render_gather' do
    before do
      allow(helper).to receive(:headers).and_return({})
      allow(helper).to receive(:render).and_return('rendered')
    end

    it 'renders the running partial for running gathers' do
      allow(helper).to receive(:gather_from_context).and_return(instance_double(Gather, status: Gather::STATE_RUNNING))
      allow(helper).to receive(:gatherer_from_context).and_return(nil)

      expect(helper.render_gather).to eq('rendered')
      expect(helper.headers['Gather']).to eq('running')
      expect(helper).to have_received(:render).with(partial: 'gathers/running', layout: false)
    end

    it 'marks voting gathers as voted when the current user has voted' do
      votes_relation = instance_double('VotesRelation')
      gather = instance_double(Gather, status: Gather::STATE_VOTING, gatherer_votes: votes_relation)
      current_user = instance_double(User, id: 9)

      allow(helper).to receive(:gather_from_context).and_return(gather)
      allow(helper).to receive(:gatherer_from_context).and_return(instance_double(Gatherer))
      helper.define_singleton_method(:cuser) { current_user }
      allow(votes_relation).to receive(:where).with(user_id: 9).and_return(instance_double('FilteredVotes', any?: true))

      helper.render_gather

      expect(helper.headers['Gather']).to eq('voted')
      expect(helper).to have_received(:render).with(partial: 'gathers/voting', layout: false)
    end

    it 'marks voting gathers as voting when the current user has not voted' do
      votes_relation = instance_double('VotesRelation')
      gather = instance_double(Gather, status: Gather::STATE_VOTING, gatherer_votes: votes_relation)
      current_user = instance_double(User, id: 9)

      allow(helper).to receive(:gather_from_context).and_return(gather)
      allow(helper).to receive(:gatherer_from_context).and_return(nil)
      helper.define_singleton_method(:cuser) { current_user }
      allow(votes_relation).to receive(:where).with(user_id: 9).and_return(instance_double('FilteredVotes',
                                                                                           any?: false))

      helper.render_gather

      expect(helper.headers['Gather']).to eq('voting')
    end

    it 'renders the picking partial for picking gathers' do
      allow(helper).to receive(:gather_from_context).and_return(instance_double(Gather, status: Gather::STATE_PICKING))
      allow(helper).to receive(:gatherer_from_context).and_return(nil)

      helper.render_gather

      expect(helper.headers['Gather']).to eq('picking')
      expect(helper).to have_received(:render).with(partial: 'gathers/picking', layout: false)
    end

    it 'renders the picking partial for finished gathers' do
      allow(helper).to receive(:gather_from_context).and_return(instance_double(Gather, status: Gather::STATE_FINISHED))
      allow(helper).to receive(:gatherer_from_context).and_return(nil)

      helper.render_gather

      expect(helper.headers['Gather']).to eq('picking')
      expect(helper).to have_received(:render).with(partial: 'gathers/picking', layout: false)
    end
  end

  describe '#gather_music_should_play?' do
    let(:user) { instance_double(User, id: 5) }
    let(:gather_users) { instance_double('GatherUsers') }
    let(:gatherer_votes) { instance_double('VoteScope') }
    let(:map_votes) { instance_double('VoteScope') }
    let(:server_votes) { instance_double('VoteScope') }
    let(:gather) do
      instance_double(
        Gather,
        users: gather_users,
        status: status,
        gatherer_votes: gatherer_votes,
        map_votes: map_votes,
        server_votes: server_votes
      )
    end
    let(:status) { Gather::STATE_VOTING }

    before do
      allow(helper).to receive(:gather_from_context).and_return(gather)
      allow(helper).to receive(:gather_current_user).and_return(user)
    end

    it 'returns false when the gather or user is missing' do
      allow(helper).to receive(:gather_from_context).and_return(nil)

      expect(helper.gather_music_should_play?).to be(false)

      allow(helper).to receive(:gather_from_context).and_return(gather)
      allow(helper).to receive(:gather_current_user).and_return(nil)

      expect(helper.gather_music_should_play?).to be(false)
    end

    it 'returns false when the user is not part of the gather' do
      allow(gather_users).to receive(:exists?).with(5).and_return(false)

      expect(helper.gather_music_should_play?).to be(false)
    end

    it 'returns false when the gather is not in voting' do
      allow(gather_users).to receive(:exists?).with(5).and_return(true)
      allow(gather).to receive(:status).and_return(Gather::STATE_RUNNING)

      expect(helper.gather_music_should_play?).to be(false)
    end

    it 'returns false when any vote has already been cast' do
      allow(gather_users).to receive(:exists?).with(5).and_return(true)
      allow(gatherer_votes).to receive(:where).with(user_id: 5).and_return(instance_double('GathererVoteQuery',
                                                                                           exists?: true))

      expect(helper.gather_music_should_play?).to be(false)
    end

    it 'returns true when the user can still vote on all categories' do
      allow(gather_users).to receive(:exists?).with(5).and_return(true)
      allow(gatherer_votes).to receive(:where).with(user_id: 5).and_return(instance_double('GathererVoteQuery',
                                                                                           exists?: false))
      allow(map_votes).to receive(:where).with(user_id: 5).and_return(instance_double('MapVoteQuery', exists?: false))
      allow(server_votes).to receive(:where).with(user_id: 5).and_return(instance_double('ServerVoteQuery',
                                                                                         exists?: false))

      expect(helper.gather_music_should_play?).to be(true)
    end
  end

  describe '#gather_archive_link' do
    it 'renders the archive link with the default button class' do
      html = helper.gather_archive_link

      expect(html).to include('Gather archive')
      expect(html).to include('class="button tiny"')
    end

    it 'renders the archive link with a custom class' do
      html = helper.gather_archive_link('button')

      expect(html).to include('Gather archive')
      expect(html).to include('class="button"')
    end
  end
end
