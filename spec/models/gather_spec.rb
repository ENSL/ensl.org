require 'rails_helper'

RSpec.describe Gather, type: :model do
  describe 'initialization' do
    it 'sets status to STATE_RUNNING on init' do
      g = Gather.new
      g.send(:init_variables)
      expect(g.status).to eq(Gather::STATE_RUNNING)
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
      expect(gx.reload.team).to be_nil
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
  end
end
