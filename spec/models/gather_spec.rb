require 'rails_helper'

RSpec.describe Gather, type: :model do
  def stub_refresh_state(gather, team1_count:, team2_count:, lobby_member: nil)
    fake_assoc = double('gatherers_assoc')

    allow(fake_assoc).to receive(:team).with(1).and_return(double(count: team1_count))
    allow(fake_assoc).to receive(:team).with(2).and_return(double(count: team2_count))
    allow(fake_assoc).to receive(:lobby).and_return(double(first: lobby_member))
    allow(gather).to receive(:gatherers).and_return(fake_assoc)
    allow(gather).to receive(:with_lock).and_yield
  end

  describe 'initialization' do
    it 'sets status to STATE_RUNNING on init' do
      g = Gather.new
      g.send(:init_variables)
      expect(g.status).to eq(Gather::STATE_RUNNING)
    end

    it 'defaults pick_strategy to default strategy' do
      gather = create(:gather)
      expect(gather.pick_strategy).to eq(Gather::PICK_STRATEGY_DEFAULT)
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

  describe 'check_captains' do
    it 'assigns turn/status and updates gatherers teams when captains change' do
      gather = create(:gather)
      ga = gather.gatherers.create!(user: create(:user))
      gb = gather.gatherers.create!(user: create(:user))
      gx = gather.gatherers.create!(user: create(:user))

      gather.update!(captain1_id: ga.id, captain2_id: gb.id)
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

  describe 'check_status' do
    it 'creates only one follow-up gather for concurrent stale transitions' do
      gather = create(:gather)
      create_list(:gatherer, 12, gather: gather)

      stale_copy_1 = Gather.find(gather.id)
      stale_copy_2 = Gather.find(gather.id)

      expect do
        stale_copy_1.update!(status: Gather::STATE_PICKING)
        stale_copy_2.update!(status: Gather::STATE_PICKING)
      end.to change { Gather.where(category_id: gather.category_id).count }.by(1)
    end
  end

  describe 'refresh' do
    it 'changes turn based on team counts' do
      gather = create(:gather)
      gather.update!(status: Gather::STATE_PICKING, turn: 1)
      # set teams so that team1 count == 2 and team2 count == 1
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
      gather.update_columns(status: Gather::STATE_PICKING, turn: 2)
      gather.reload
      stub_refresh_state(gather, team1_count: 2, team2_count: 3)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(1)
    end

    it 'switches to team 2 when team 1 reaches the 4-3 pick window' do
      gather = create(:gather)
      gather.update_columns(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      stub_refresh_state(gather, team1_count: 4, team2_count: 3)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(2)
    end

    it 'switches back to team 1 when team 2 reaches the 5-4 pick window' do
      gather = create(:gather)
      gather.update_columns(status: Gather::STATE_PICKING, turn: 2)
      gather.reload
      stub_refresh_state(gather, team1_count: 4, team2_count: 5)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(1)
    end

    it 'moves the last lobby player to team 2 in the 6-5 state' do
      gather = create(:gather)
      gather.update_columns(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      lobby_member = instance_double(Gatherer)
      allow(lobby_member).to receive(:update!)
      stub_refresh_state(gather, team1_count: 6, team2_count: 5, lobby_member: lobby_member)

      gather.refresh(nil)

      expect(lobby_member).to have_received(:update!).with(team: 2, skip_callbacks: true)
      expect(gather.reload.turn).to eq(2)
    end

    it 'handles the 6-5 state when there is no lobby member to move' do
      gather = create(:gather)
      gather.update_columns(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      stub_refresh_state(gather, team1_count: 6, team2_count: 5, lobby_member: nil)

      expect { gather.refresh(nil) }.not_to raise_error
      expect(gather.reload.turn).to eq(2)
    end

    it 'does nothing when team counts are outside the transition windows' do
      gather = create(:gather)
      gather.update_columns(status: Gather::STATE_PICKING, turn: 1)
      gather.reload
      stub_refresh_state(gather, team1_count: 1, team2_count: 1)

      expect(gather).not_to receive(:with_lock)

      gather.refresh(nil)

      expect(gather.reload.turn).to eq(1)
      expect(gather.status).to eq(Gather::STATE_PICKING)
    end
  end
end
