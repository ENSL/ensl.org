# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
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

      first_pick_later.update!(team: 1, pick_order: 1, updated_at: 3.minutes.ago)
      first_pick_earlier.update!(team: 1, pick_order: 1, updated_at: 4.minutes.ago)
      second_pick.update!(team: 1, pick_order: 2, updated_at: 5.minutes.ago)
      no_pick_earlier.update!(team: 1)
      no_pick_later.update!(team: 1)
      no_pick_earlier.update!(pick_order: nil, updated_at: 2.minutes.ago)
      no_pick_later.update!(pick_order: nil, updated_at: 1.minute.ago)
      other_team.update!(team: 2, pick_order: 1, updated_at: 6.minutes.ago)

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

  describe 'vote cleanup' do
    it "removes the departing user's gather votes and preserves other users' votes" do
      gather = create(:gather)
      departing = create(:gatherer, gather: gather)
      candidate = create(:gatherer, gather: gather)
      gather_map = GatherMap.create!(gather: gather, map: create(:map), votes: 0)
      gather_server = GatherServer.create!(gather: gather, server: create(:server), votes: 0)
      other_user = create(:user)

      departing_vote_ids = [candidate, gather_map, gather_server].map do |votable|
        Vote.create!(user: departing.user, votable: votable).id
      end
      other_vote = Vote.create!(user: other_user, votable: candidate)

      departing.destroy!

      expect(Vote.where(id: departing_vote_ids)).to be_empty
      expect(Vote.exists?(other_vote.id)).to be true
    end
  end

  describe 'change_turn' do
    it 'switches turns after the first pick in the default strategy' do
      gather = create(:gather, status: Gather::STATE_PICKING, turn: 1)
      captain1 = create(:gatherer, gather: gather)
      captain2 = create(:gatherer, gather: gather)
      player = create(:gatherer, gather: gather)
      captain1.update_columns(team: 1, pick_order: 1)
      captain2.update_columns(team: 2, pick_order: 2)
      gather.update_columns(captain1_id: captain1.id, captain2_id: captain2.id)

      player.update!(team: 1)

      expect(gather.reload.turn).to eq(2)
    end

    it 'keeps and then switches turns across a two-pick segment' do
      gather = create(:gather, status: Gather::STATE_PICKING, turn: 2)
      captain1 = create(:gatherer, gather: gather)
      captain2 = create(:gatherer, gather: gather)
      first_team1_pick = create(:gatherer, gather: gather)
      first_team2_pick = create(:gatherer, gather: gather)
      second_team2_pick = create(:gatherer, gather: gather)
      captain1.update_columns(team: 1, pick_order: 1)
      captain2.update_columns(team: 2, pick_order: 2)
      first_team1_pick.update_columns(team: 1, pick_order: 3)
      gather.update_columns(captain1_id: captain1.id, captain2_id: captain2.id)

      first_team2_pick.update!(team: 2)
      expect(gather.reload.turn).to eq(2)

      second_team2_pick.update!(team: 2)
      expect(gather.reload.turn).to eq(1)
    end

    it 'switches after every pick for the 1-1-1-1 strategy' do
      gather = create(:gather, pick_strategy: '1-1-1-1', status: Gather::STATE_PICKING, turn: 1)
      captain1 = create(:gatherer, gather: gather)
      captain2 = create(:gatherer, gather: gather)
      team1_pick = create(:gatherer, gather: gather)
      team2_pick = create(:gatherer, gather: gather)
      captain1.update_columns(team: 1, pick_order: 1)
      captain2.update_columns(team: 2, pick_order: 2)
      gather.update_columns(captain1_id: captain1.id, captain2_id: captain2.id)

      team1_pick.update!(team: 1)
      expect(gather.reload.turn).to eq(2)

      team2_pick.update!(team: 2)
      expect(gather.reload.turn).to eq(1)
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

  describe 'delegated helper methods' do
    describe '.status_from_key' do
      it 'maps known status keys and returns nil for unknown values' do
        expect(described_class.status_from_key('away')).to eq(described_class::STATE_AWAY)
        expect(described_class.status_from_key(:active)).to eq(described_class::STATE_ACTIVE)
        expect(described_class.status_from_key('unknown')).to be_nil
      end
    end

    describe '#update_for_actor' do
      let(:gather) { create(:gather, :running) }
      let(:gatherer) { create(:gatherer, gather: gather, user: create(:user)) }
      let(:actor) { create(:user, :admin) }
      let(:raw_params) { ActionController::Parameters.new(gatherer: { team: 1 }) }

      before do
        allow(Gatherer).to receive(:params).and_return(team: 1)
        allow(Gathers::Broadcaster).to receive(:call)
      end

      it 'returns an unauthorized result when actor cannot update' do
        allow(gatherer).to receive(:can_update?).and_return(false)

        result = gatherer.update_for_actor(raw_params, actor)

        expect(result.authorized).to be false
        expect(result.updated).to be false
      end

      it 'updates and broadcasts when actor is authorized and update succeeds' do
        allow(gatherer).to receive(:can_update?).and_return(true)
        allow(gatherer).to receive(:update).and_return(true)

        result = gatherer.update_for_actor(raw_params, actor)

        expect(result.authorized).to be true
        expect(result.updated).to be true
        expect(Gathers::Broadcaster).to have_received(:call).with(gather)
      end
    end

    describe '#update_status_from_key' do
      it 'updates status and broadcasts for valid keys' do
        gather = create(:gather, :running)
        gatherer = create(:gatherer, gather: gather, user: create(:user), status: Gatherer::STATE_ACTIVE)
        allow(Gathers::Broadcaster).to receive(:call)

        result = gatherer.update_status_from_key('away')

        expect(result).to be true
        expect(gatherer.reload.status).to eq(Gatherer::STATE_AWAY)
        expect(Gathers::Broadcaster).to have_received(:call).with(gather)
      end

      it 'returns false and does not broadcast for invalid keys' do
        gather = create(:gather, :running)
        gatherer = create(:gatherer, gather: gather, user: create(:user), status: Gatherer::STATE_ACTIVE)
        allow(Gathers::Broadcaster).to receive(:call)

        result = gatherer.update_status_from_key('nope')

        expect(result).to be false
        expect(gatherer.reload.status).to eq(Gatherer::STATE_ACTIVE)
        expect(Gathers::Broadcaster).not_to have_received(:call)
      end
    end

    describe '#reactivate_if_returning!' do
      let(:gather) { create(:gather, :running) }

      it 'marks a leaving gatherer as active' do
        gatherer = create(:gatherer, gather: gather, user: create(:user), status: Gatherer::STATE_LEAVING)

        gatherer.reactivate_if_returning!

        expect(gatherer.reload.status).to eq(Gatherer::STATE_ACTIVE)
      end

      it 'leaves other statuses untouched' do
        gatherer = create(:gatherer, gather: gather, user: create(:user), status: Gatherer::STATE_AWAY)

        gatherer.reactivate_if_returning!

        expect(gatherer.reload.status).to eq(Gatherer::STATE_AWAY)
      end
    end
  end

  describe 'guard and fallback branches' do
    it 'adds an error when username does not match any user' do
      gatherer = build(:gatherer, username: 'not_a_real_user_123')
      gatherer.define_singleton_method(:t) { |_key| 'Wrong username' }

      gatherer.validate_username

      expect(gatherer.errors[:username]).to be_present
    end

    it 'does not restart an already voting gather' do
      gather = create(:gather, status: Gather::STATE_VOTING)
      create_list(:gatherer, Gather::FULL, gather: gather)

      expect { gather.start_voting_if_full! }.not_to(change { gather.reload.status })
    end

    it 'skips notifications for profiles that opted out of PM notifications' do
      gather = create(:gather)
      opted_out = create(:user)
      create(:profile, user: opted_out, notify_gather: 1, notify_pms: false)
      allow(Notifications).to receive(:gather)

      create(:gatherer, gather: gather, user: create(:user))
      allow(gather.gatherers).to receive(:count).and_return(Gather::NOTIFY)

      gather.notify_interested_users_if_threshold_reached!

      expect(Notifications).not_to have_received(:gather).with(opted_out, gather)
    end

    it 'returns false for username updates by non-admin and non-moderator users' do
      gather = create(:gather)
      gatherer = create(:gatherer, gather: gather, user: create(:user))
      actor = create(:user)

      expect(gatherer.can_update?(actor, { 'username' => 'new_name' })).to be(false)
    end

    it 'returns false for captain picks in the restricted 2-<3 composition' do
      gather = create(:gather, turn: 1)
      captain_user = create(:user)
      captain = create(:gatherer, gather: gather, user: captain_user, team: 1)
      gather.update!(captain1: captain)

      target = create(:gatherer, gather: gather, user: create(:user), team: nil)
      create_list(:gatherer, 1, gather: gather, team: 1)
      create_list(:gatherer, 2, gather: gather, team: 2)

      expect(target.can_update?(captain_user, {})).to be(false)
    end

    it 'checks join ownership, bans, capacity, and duplicate membership' do
      gather = create(:gather, status: Gather::STATE_RUNNING)
      user = create(:user)
      gatherer = build(:gatherer, gather: gather, user: user)
      allow(user).to receive(:banned?).with(Ban::TYPE_GATHER).and_return(false)

      expect(gatherer.can_create?(user)).to be true
      expect(gatherer.can_create?(nil)).to be false
      expect(gatherer.can_create?(create(:user))).to be false

      create(:gatherer, gather: gather, user: user)
      expect(gatherer.can_create?(user)).to be false
    end

    it 'allows owners and privileged users to leave only running gathers' do
      gather = create(:gather, status: Gather::STATE_RUNNING)
      owner = create(:user)
      gatherer = create(:gatherer, gather: gather, user: owner)
      admin = create(:user, :admin)
      moderator = create(:user, :gather_moderator)

      expect(gatherer.can_destroy?(owner)).to be true
      expect(gatherer.can_destroy?(admin)).to be true
      expect(gatherer.can_destroy?(moderator)).to be true
      expect(gatherer.can_destroy?(nil)).to be false

      gather.update_columns(status: Gather::STATE_FINISHED)
      expect(gatherer.can_destroy?(owner)).to be false
    end

    it "recognizes either captain only on that captain's turn" do
      gather = create(:gather, status: Gather::STATE_PICKING, turn: 2)
      captain1 = create(:gatherer, gather: gather, team: 1)
      captain2 = create(:gatherer, gather: gather, team: 2)
      create_list(:gatherer, 2, gather: gather, team: 1)
      target = create(:gatherer, gather: gather, team: nil)
      gather.update_columns(captain1_id: captain1.id, captain2_id: captain2.id)

      expect(target.can_update?(captain1.user)).to be false
      expect(target.can_update?(captain2.user)).to be true

      gather.update_columns(turn: nil)
      expect(target.can_update?(captain2.user)).to be false
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
