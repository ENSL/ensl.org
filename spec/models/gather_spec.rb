# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gather, type: :model do
  def stub_refresh_state(gather, team_one_count:, team_two_count:, lobby_member: nil)
    fake_assoc = double('gatherers_assoc')

    allow(fake_assoc).to receive(:team).with(1).and_return(double(count: team_one_count))
    allow(fake_assoc).to receive(:team).with(2).and_return(double(count: team_two_count))
    allow(fake_assoc).to receive(:lobby).and_return(double(first: lobby_member))
    allow(gather).to receive(:gatherers).and_return(fake_assoc)
    allow(gather).to receive(:with_lock).and_yield
  end

  describe 'initialization' do
    it 'sets status to STATE_RUNNING on init' do
      g = Gather.new
      g.send(:initialize_state)
      expect(g.status).to eq(Gather::STATE_RUNNING)
    end

    it 'defaults pick_strategy to default strategy' do
      gather = create(:gather)
      expect(gather.pick_strategy).to eq(Gather::PICK_STRATEGY_DEFAULT)
    end

    it 'returns player count for a game category when present' do
      category = create(:category, name: 'ns2', domain: Category::DOMAIN_GAMES)
      gather = create(:gather, category: category)
      create_list(:gatherer, 3, gather: gather)

      expect(described_class.player_count_for_game('ns2')).to eq(3)
    end
  end

  describe 'pick_strategy' do
    it 'is immutable after create' do
      gather = create(:gather)

      gather.pick_strategy = 'random'
      expect(gather).to be_invalid
      expect(gather.errors[:pick_strategy]).to include('cannot be changed')
    end
  end

  describe '#admin_update' do
    it 'updates the gather and broadcasts on success' do
      gather = create(:gather)
      allow(Gathers::Broadcaster).to receive(:call)

      expect(gather.admin_update(turn: 1)).to be true
      expect(gather.reload.turn).to eq(1)
      expect(Gathers::Broadcaster).to have_received(:call).with(gather)
    end

    it 'returns false and does not broadcast when the update fails' do
      gather = create(:gather)
      allow(gather).to receive(:update).and_return(false)
      allow(Gathers::Broadcaster).to receive(:call)

      expect(gather.admin_update(turn: 1)).to be false
      expect(Gathers::Broadcaster).not_to have_received(:call)
    end
  end

  describe 'captain team assignment' do
    it 'assigns turn/status and updates gatherers teams when captains change' do
      gather = create(:gather)
      ga = gather.gatherers.create!(user: create(:user))
      gb = gather.gatherers.create!(user: create(:user))
      gx = gather.gatherers.create!(user: create(:user))

      gather.admin_update(captain1_id: ga.id, captain2_id: gb.id)
      gather.reload
      expect(gather.turn).to eq(1)
      expect(gather.status).to eq(Gather::STATE_PICKING)
      expect(ga.reload.team).to eq(1)
      expect(gb.reload.team).to eq(2)
      expect(ga.reload.pick_order).to eq(1)
      expect(gb.reload.pick_order).to eq(2)
      expect(gx.reload.team).to be_nil
      expect(gx.reload.pick_order).to be_nil
    end
  end

  describe 'picking preparation' do
    it 'creates only one follow-up gather for concurrent stale transitions' do
      gather = create(:gather)
      create_list(:gatherer, 12, gather: gather)

      stale_copy_one = Gather.find(gather.id)
      stale_copy_two = Gather.find(gather.id)

      expect do
        stale_copy_one.send(:complete_voting!)
        stale_copy_two.send(:complete_voting!)
      end.to change { Gather.where(category_id: gather.category_id).count }.by(1)
    end
  end

  describe 'refresh' do
    it 'changes turn based on team counts' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 1)
      # set teams so that team one count == 2 and team two count == 1
      gather.gatherers.create!(user: create(:user), team: 1)
      gather.gatherers.create!(user: create(:user), team: 1)
      gather.gatherers.create!(user: create(:user), team: 2)

      gather.refresh(nil)
      gather.reload
      expect(gather.turn).to eq(2)
    end

    it 'marks finished when both teams have 6' do
      gather = create(:gather)
      # create the gatherers, then ensure gather is in PICKING state before refresh
      gather.update!(status: Gather::STATE_PICKING)
      # stub counts to simulate both teams full
      fake_assoc = double('gatherers_assoc')
      allow(fake_assoc).to receive(:team).with(1).and_return(double(count: 6))
      allow(fake_assoc).to receive(:team).with(2).and_return(double(count: 6))
      allow(fake_assoc).to receive(:lobby).and_return(double(first: nil))
      allow(gather).to receive(:gatherers).and_return(fake_assoc)
      gather.refresh(nil)
      gather.reload
      expect(gather.status).to eq(Gather::STATE_FINISHED)
    end

    it 'switches to team 1 when team 2 has the next pick window' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 2)
      gather.reload
      stub_refresh_state(gather, team_one_count: 2, team_two_count: 3)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(1)
    end

    it 'switches to team 2 when team 1 reaches the 4-3 pick window' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      stub_refresh_state(gather, team_one_count: 4, team_two_count: 3)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(2)
    end

    it 'switches back to team 1 when team 2 reaches the 5-4 pick window' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 2)
      gather.reload
      stub_refresh_state(gather, team_one_count: 4, team_two_count: 5)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(1)
    end

    it 'moves the last lobby player to team 2 in the 6-5 state' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      lobby_member = instance_double(Gatherer)
      allow(lobby_member).to receive(:update!)
      stub_refresh_state(gather, team_one_count: 6, team_two_count: 5, lobby_member: lobby_member)

      gather.refresh(nil)

      expect(lobby_member).to have_received(:update!).with(team: 2, skip_callbacks: true)
      expect(gather.reload.turn).to eq(2)
    end

    it 'handles the 6-5 state when there is no lobby member to move' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      stub_refresh_state(gather, team_one_count: 6, team_two_count: 5, lobby_member: nil)

      expect { gather.refresh(nil) }.not_to raise_error
      expect(gather.reload.turn).to eq(2)
    end

    it 'does nothing when team counts are outside the transition windows' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      stub_refresh_state(gather, team_one_count: 1, team_two_count: 1)

      expect(gather).not_to receive(:with_lock)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(1)
      expect(gather.status).to eq(Gather::STATE_PICKING)
    end
  end

  describe 'status and timeout helpers' do
    it 'assigns only map1 when exactly one gather map exists' do
      gather = create(:gather)
      map = create(:map)
      gather.gather_maps.destroy_all
      gather.gather_servers.destroy_all
      gather.gather_maps.create!(map: map)
      allow(gather.gatherers).to receive(:most_voted).and_return([nil, nil])

      gather.send(:complete_voting!)

      expect(gather.map1).to eq(gather.gather_maps.ordered.first)
      expect(gather.map2).to be_nil
    end

    it 'uses default voting timeout outside test environment' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      expect(create(:gather).voting_timeout).to eq(Gather::VOTING_TIMEOUT_SECONDS)
    end

    it 'returns nil voting start time outside voting and picking states' do
      gather = create(:gather, status: Gather::STATE_RUNNING)

      expect(gather.voting_start_time).to be_nil
    end

    it 'returns zero voting time remaining when gather is not voting' do
      gather = create(:gather, status: Gather::STATE_PICKING)

      expect(gather.voting_time_remaining).to eq(0)
    end

    it 'reports remaining voting time and clamps expired voting to zero' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_VOTING)
      allow(gather).to receive(:voting_start_time).and_return(5.seconds.ago)
      allow(gather).to receive(:voting_timeout).and_return(10)

      expect(gather.voting_time_remaining).to be_between(4, 5)

      allow(gather).to receive(:voting_start_time).and_return(20.seconds.ago)
      expect(gather.voting_time_remaining).to eq(0)
    end

    it 'broadcasts only when refresh changes the status' do
      gather = create(:gather, status: Gather::STATE_RUNNING)
      allow(Gathers::Broadcaster).to receive(:call)
      allow(gather).to receive(:refresh)

      gather.refresh_and_broadcast_if_status_changed!
      expect(Gathers::Broadcaster).not_to have_received(:call)

      allow(gather).to receive(:refresh) { gather.status = Gather::STATE_PICKING }
      gather.refresh_and_broadcast_if_status_changed!
      expect(Gathers::Broadcaster).to have_received(:call).with(gather)
    end
  end

  describe 'authorization helpers' do
    it 'allows admins and gather moderators to create and update gathers' do
      admin = instance_double(User, admin?: true, gather_moderator?: false)
      moderator = instance_double(User, admin?: false, gather_moderator?: true)
      user = instance_double(User, admin?: false, gather_moderator?: false)
      gather = build(:gather)

      expect(gather.can_create?(admin)).to be true
      expect(gather.can_create?(moderator)).to be true
      expect(gather.can_create?(user)).to be_nil
      expect(gather.can_update?(admin)).to be true
      expect(gather.can_update?(moderator)).to be true
      expect(gather.can_update?(user)).to be_nil
    end
  end

  describe '#populate_maps_and_servers' do
    it 'uses HLDS servers for category 44' do
      gather = create(:gather)
      gather.category_id = 44

      category = instance_double(Category)
      maps_scope = double('maps_scope')
      servers_scope = double('servers_scope')
      hlds_scope = double('hlds_scope')
      active_scope = double('active_scope')
      ordered_scope = [build_stubbed(:server)]

      allow(gather).to receive(:category).and_return(category)
      allow(gather).to receive(:maps).and_return([])
      allow(gather).to receive(:servers).and_return([])
      allow(category).to receive(:maps).and_return(maps_scope)
      allow(maps_scope).to receive(:basic).and_return(maps_scope)
      allow(maps_scope).to receive(:classic).and_return([])
      allow(category).to receive(:servers).and_return(servers_scope)
      allow(servers_scope).to receive(:hlds).and_return(hlds_scope)
      allow(hlds_scope).to receive(:active).and_return(active_scope)
      allow(active_scope).to receive(:ordered).and_return(ordered_scope)

      expect(servers_scope).not_to receive(:active)
      gather.send(:populate_maps_and_servers)
    end
  end
end
