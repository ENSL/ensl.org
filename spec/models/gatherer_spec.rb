require 'rails_helper'

RSpec.describe Gatherer, type: :model do
  describe 'start_gather and notify' do
    it 'sets gather status to STATE_VOTING when FULL reached' do
      gather = create(:gather)
      # create FULL-1 gatherers
      (Gather::FULL - 1).times do
        gather.gatherers.create!(user: create(:user))
      end
      expect(gather.gatherers.count).to eq(Gather::FULL - 1)

      # last one should trigger start_gather via after_create
      gather.gatherers.create!(user: create(:user))
      gather.reload
      expect(gather.status).to eq(Gather::STATE_VOTING)
    end

    it 'notifies users when NOTIFY threshold reached' do
      gather = create(:gather)
      target = create(:user)
      create(:profile, user: target, notify_gather: 1, notify_pms: true)
      allow(Notifications).to receive(:gather)

      # create NOTIFY-1 gatherers
      (Gather::NOTIFY - 1).times do
        gather.gatherers.create!(user: create(:user))
      end

      # this creation should trigger notifications
      gather.gatherers.create!(user: create(:user))
      expect(Notifications).to have_received(:gather).at_least(:once)
    end
  end

  describe 'change_turn' do
    it 'updates gather.turn when a gatherer gets a team' do
      gather = create(:gather)
      g1 = gather.gatherers.create!(user: create(:user))
      expect(gather.turn).to be_nil
      g1.update!(team: 1)
      gather.reload
      expect(gather.turn).to eq(2)
    end

    it 'moves lone lobby member to other team when applicable' do
      gather = create(:gather)
      # create initial team members
      t1 = gather.gatherers.create!(user: create(:user), team: 1)
      t2 = gather.gatherers.create!(user: create(:user), team: 2)
      lobby = gather.gatherers.create!(user: create(:user), team: nil)

      # change t1's team to trigger change_turn
      t1.update!(team: 2)
      lobby.reload
      expect([1, 2]).to include(lobby.team)
    end
  end
end
