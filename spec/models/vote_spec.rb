# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vote, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, :game) }
  let(:gather) { create(:gather, category: category) }

  let!(:gatherer) { Gatherer.create!(gather: gather, user: user, confirm: true) }

  def create_gather_map(name: 'ns_test')
    map = create(:map, name: name, category_id: category.id)
    GatherMap.create!(gather: gather, map: map, votes: 0)
  end

  def create_gather_server(id: nil)
    server = create(:server, active: true)
    attrs = { gather: gather, server: server, votes: 0 }
    attrs[:id] = id if id
    GatherServer.create!(**attrs)
  end

  def build_vote(votable_type:, votable: nil)
    vote = described_class.new(user: user, user_id: user.id, votable_type: votable_type, votable_id: 1)
    allow(vote).to receive(:votable).and_return(votable) if votable
    vote
  end

  describe '#can_create?' do
    it 'returns false without a current user' do
      expect(Vote.new.can_create?(nil)).to be(false)
    end

    it 'blocks option votes when the poll already has a vote from the user' do
      poll = double(voted?: true)
      option = double(poll: poll)
      vote = build_vote(votable_type: 'Option', votable: option)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'allows option votes when the poll has not been voted yet' do
      poll = double(voted?: false)
      option = double(poll: poll)
      vote = build_vote(votable_type: 'Option', votable: option)

      expect(vote.can_create?(user)).to be(true)
    end

    it 'allows votable types without a specialized policy' do
      vote = build_vote(votable_type: 'Article', votable: double)

      expect(vote.can_create?(user)).to be(true)
    end

    it 'blocks gather votes for users outside the gather' do
      users = double(exists?: false)
      gather = double(users: users)
      votable = double(gather: gather)
      vote = build_vote(votable_type: 'GatherMap', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks gatherer votes unless the gather is in the voting state' do
      gatherer_votes = double
      allow(gatherer_votes).to receive(:where).and_return(gatherer_votes)
      allow(gatherer_votes).to receive(:exists?).and_return(false)
      allow(gatherer_votes).to receive(:count).and_return(0)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_RUNNING, users: users, gatherer_votes: gatherer_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'Gatherer', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks duplicate gatherer votes for the same user and choice' do
      duplicate_scope = double(exists?: true)
      all_scope = double(count: 0)
      gatherer_votes = double
      allow(gatherer_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(gatherer_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, gatherer_votes: gatherer_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'Gatherer', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks gatherer votes after two picks have already been made' do
      duplicate_scope = double(exists?: false)
      all_scope = double(count: 2)
      gatherer_votes = double
      allow(gatherer_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(gatherer_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, gatherer_votes: gatherer_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'Gatherer', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'allows gatherer votes when membership and vote limits are valid' do
      duplicate_scope = double(exists?: false)
      all_scope = double(count: 1)
      gatherer_votes = double
      allow(gatherer_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(gatherer_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, gatherer_votes: gatherer_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'Gatherer', votable: votable)

      expect(vote.can_create?(user)).to be(true)
    end

    it 'blocks map votes once the gather is finished' do
      map_votes = double
      users = double(exists?: true)
      gather = double(status: Gather::STATE_FINISHED, users: users, map_votes: map_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'GatherMap', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks duplicate votes on the same map' do
      duplicate_scope = double(count: 1)
      all_scope = double(count: 1)
      map_votes = double
      allow(map_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(map_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, map_votes: map_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'GatherMap', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks additional map votes after the per-gather limit is reached' do
      duplicate_scope = double(count: 0)
      all_scope = double(count: 2)
      map_votes = double
      allow(map_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(map_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, map_votes: map_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'GatherMap', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks server votes once the gather is finished' do
      users = double(exists?: true)
      gather = double(status: Gather::STATE_FINISHED, users: users, server_votes: double)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'GatherServer', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks duplicate votes on the same server' do
      duplicate_scope = double(exists?: true)
      all_scope = double(count: 0)
      server_votes = double
      allow(server_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(server_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, server_votes: server_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'GatherServer', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'blocks additional server votes after the per-gather limit is reached' do
      duplicate_scope = double(exists?: false)
      all_scope = double(count: 2)
      server_votes = double
      allow(server_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(server_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, server_votes: server_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'GatherServer', votable: votable)

      expect(vote.can_create?(user)).to be(false)
    end

    it 'allows server votes when membership and vote limits are valid' do
      duplicate_scope = double(exists?: false)
      all_scope = double(count: 1)
      server_votes = double
      allow(server_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(server_votes).to receive(:where).with(user_id: user.id).and_return(all_scope)
      users = double(exists?: true)
      gather = double(status: Gather::STATE_VOTING, users: users, server_votes: server_votes)
      votable = double(gather: gather, id: 1)
      vote = build_vote(votable_type: 'GatherServer', votable: votable)

      expect(vote.can_create?(user)).to be(true)
    end
  end

  describe '#validate_gather_vote_limits' do
    it 'adds an invalid gather error when the votable has no gather' do
      votable = double(gather: nil)
      vote = build_vote(votable_type: 'GatherMap', votable: votable)

      vote.valid?

      expect(vote.errors[:base]).to include('Invalid gather')
    end

    it 'adds an error when the map vote limit has been reached' do
      map_votes = double
      allow(map_votes).to receive(:where).with(user_id: user.id).and_return(double(count: 2))
      gather = double(map_votes: map_votes)
      votable = double(gather: gather, respond_to?: true)
      vote = build_vote(votable_type: 'GatherMap', votable: votable)

      vote.valid?

      expect(vote.errors[:base]).to include('Maximum map votes reached for this gather')
    end

    it 'adds duplicate and max-vote errors for server votes when both conditions apply' do
      duplicate_scope = double(exists?: true)
      count_scope = double(count: 2)
      server_votes = double
      allow(server_votes).to receive(:where).with(user_id: user.id, votable_id: 1).and_return(duplicate_scope)
      allow(server_votes).to receive(:where).with(user_id: user.id).and_return(count_scope)
      gather = double(server_votes: server_votes)
      votable = double(gather: gather, id: 1, respond_to?: true)
      vote = build_vote(votable_type: 'GatherServer', votable: votable)

      vote.valid?

      expect(vote.errors[:base]).to include('You have already voted for this server')
      expect(vote.errors[:base]).to include('Maximum server votes reached for this gather')
    end

    it 'does not add gather limit errors for unsupported votable types' do
      vote = build_vote(votable_type: 'Option', votable: double)

      vote.valid?

      expect(vote.errors[:base]).to be_empty
    end

    it 'does not add errors when the user or gather interface is unavailable' do
      vote_without_user = described_class.new(votable_type: 'GatherMap')
      allow(vote_without_user).to receive(:votable).and_return(double(respond_to?: false))

      vote_without_user.valid?

      expect(vote_without_user.errors[:base]).to be_empty
    end
  end

  describe 'vote counter callbacks' do
    it 'updates both the option and its poll counters' do
      poll_class = class_double(Poll, increment_counter: nil, decrement_counter: nil)
      option_class = class_double(Option, increment_counter: nil, decrement_counter: nil)
      poll = double(id: 10, class: poll_class)
      option = double(id: 20, poll: poll, class: option_class)
      vote = described_class.new(votable_type: 'Option')
      allow(vote).to receive(:votable).and_return(option)

      vote.increase_votes
      vote.decrease_votes

      expect(poll_class).to have_received(:increment_counter).with(:votes, 10)
      expect(poll_class).to have_received(:decrement_counter).with(:votes, 10)
      expect(option_class).to have_received(:increment_counter).with(:votes, 20)
      expect(option_class).to have_received(:decrement_counter).with(:votes, 20)
    end
  end

  it 'allows map vote even if server vote exists' do
    gather_map = create_gather_map(name: 'ns_alpha')
    gather_server = create_gather_server(id: gather_map.id)

    expect(gather_server.id).to eq(gather_map.id)

    Vote.create!(user: user, votable: gather_server)

    map_vote = Vote.new(user: user, votable: gather_map)
    expect(map_vote.can_create?(user)).to be true
    expect { map_vote.save! }.to change(Vote, :count).by(1)
  end

  it 'prevents duplicate vote on the same map but allows another map' do
    gather_map_one = create_gather_map(name: 'ns_map_one')
    gather_map_two = create_gather_map(name: 'ns_map_two')

    Vote.create!(user: user, votable: gather_map_one)

    duplicate_vote = Vote.new(user: user, votable: gather_map_one)
    expect(duplicate_vote.can_create?(user)).to be false
    expect(duplicate_vote.valid?).to be false
    expect(duplicate_vote.errors[:user_id]).to be_present

    other_map_vote = Vote.new(user: user, votable: gather_map_two)
    expect(other_map_vote.can_create?(user)).to be true
    expect { other_map_vote.save! }.to change(Vote, :count).by(1)
  end

  it 'prevents more than two map votes per user per gather' do
    map1 = create_gather_map(name: 'ns_map_a')
    map2 = create_gather_map(name: 'ns_map_b')
    map3 = create_gather_map(name: 'ns_map_c')

    Vote.create!(user: user, votable: map1)
    Vote.create!(user: user, votable: map2)

    third_vote = Vote.new(user: user, votable: map3)
    expect(third_vote.can_create?(user)).to be false
    expect { third_vote.save }.to raise_error(ActiveRecord::RecordInvalid).or change(Vote, :count).by(0)
  end
end
