require 'rails_helper'

RSpec.describe Gatherer, type: :model do
  describe '.for_pick_list' do
    it 'uses ordered lobby listing when team is nil' do
      gather = create(:gather)
      captain1 = create(:gatherer, gather: gather, team: nil)
      captain2 = create(:gatherer, gather: gather, team: nil)
      other = create(:gatherer, gather: gather, team: nil)
      gather.update!(captain1: captain1, captain2: captain2)

      expected_ids = gather.gatherers.ordered.team(nil).pluck(:id)
      result_ids = gather.gatherers.for_pick_list(nil).pluck(:id)

      expect(result_ids).to eq(expected_ids)
      expect(result_ids).to include(other.id)
    end

    it 'orders team list by pick_order first and null pick_order last' do
      gather = create(:gather)

      first_pick_later = create(:gatherer, gather: gather, team: nil)
      first_pick_earlier = create(:gatherer, gather: gather, team: nil)
      second_pick = create(:gatherer, gather: gather, team: nil)
      no_pick_earlier = create(:gatherer, gather: gather, team: nil)
      no_pick_later = create(:gatherer, gather: gather, team: nil)
      other_team = create(:gatherer, gather: gather, team: nil)

      first_pick_later.update_columns(team: 1, pick_order: 1, updated_at: 3.minutes.ago)
      first_pick_earlier.update_columns(team: 1, pick_order: 1, updated_at: 4.minutes.ago)
      second_pick.update_columns(team: 1, pick_order: 2, updated_at: 5.minutes.ago)
      no_pick_earlier.update_columns(team: 1, pick_order: nil, updated_at: 2.minutes.ago)
      no_pick_later.update_columns(team: 1, pick_order: nil, updated_at: 1.minute.ago)
      other_team.update_columns(team: 2, pick_order: 1, updated_at: 6.minutes.ago)

      result_ids = gather.gatherers.for_pick_list(1).pluck(:id)

      expect(result_ids).to eq([
                                 first_pick_earlier.id,
                                 first_pick_later.id,
                                 second_pick.id,
                                 no_pick_earlier.id,
                                 no_pick_later.id
                               ])
      expect(result_ids).not_to include(other_team.id)
    end
  end

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

    it 'assigns linear pick_order when picked' do
      gather = create(:gather)
      c1 = gather.gatherers.create!(user: create(:user), team: 1, pick_order: 1)
      c2 = gather.gatherers.create!(user: create(:user), team: 2, pick_order: 2)
      _ = [c1, c2]
      player = gather.gatherers.create!(user: create(:user), team: nil)

      player.update!(team: 1)

      expect(player.reload.pick_order).to eq(3)
    end

    it 'stores global pick_order correctly when both teams pick players' do
      gather = create(:gather)
      captain1 = gather.gatherers.create!(user: create(:user), team: 1, pick_order: 1)
      captain2 = gather.gatherers.create!(user: create(:user), team: 2, pick_order: 2)

      pick3_team1 = gather.gatherers.create!(user: create(:user), team: nil)
      pick4_team2 = gather.gatherers.create!(user: create(:user), team: nil)
      pick5_team2 = gather.gatherers.create!(user: create(:user), team: nil)

      pick3_team1.update!(team: 1)
      pick4_team2.update!(team: 2)
      pick5_team2.update!(team: 2)

      expected_orders = {
        captain1.id => 1,
        captain2.id => 2,
        pick3_team1.id => 3,
        pick4_team2.id => 4,
        pick5_team2.id => 5
      }

      actual_orders = gather.gatherers.where(id: expected_orders.keys).pluck(:id, :pick_order).to_h
      expect(actual_orders).to eq(expected_orders)
    end
  end
end
