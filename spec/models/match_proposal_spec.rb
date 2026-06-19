# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchProposal, type: :model do
  let(:contest) { create(:contest) }
  let(:user1) { create(:user_with_team) }
  let(:team1) { user1.team }
  let(:user2) { create(:user_with_team) }
  let(:team2) { user2.team }
  let(:cont1) { create(:contester, team: team1, contest: contest) }
  let(:cont2) { create(:contester, team: team2, contest: contest) }
  let(:match) { create(:match, contest: contest, contester1: cont1, contester2: cont2) }

  describe 'constants' do
    it 'defines status constants' do
      expect(MatchProposal::STATUS_PENDING).to eq(0)
      expect(MatchProposal::STATUS_REVOKED).to eq(1)
      expect(MatchProposal::STATUS_REJECTED).to eq(2)
      expect(MatchProposal::STATUS_CONFIRMED).to eq(3)
      expect(MatchProposal::STATUS_DELAYED).to eq(4)
    end

    it 'defines confirmation limit' do
      expect(MatchProposal::CONFIRMATION_LIMIT).to eq(30)
    end
  end

  describe 'associations' do
    it 'belongs to match' do
      proposal = MatchProposal.new
      expect(proposal.respond_to?(:match)).to be true
    end

    it 'belongs to team' do
      proposal = MatchProposal.new
      expect(proposal.respond_to?(:team)).to be true
    end
  end

  describe 'validations' do
    it 'requires match presence' do
      proposal = MatchProposal.new(team: team1, proposed_time: 1.day.from_now)
      expect(proposal).not_to be_valid
      expect(proposal.errors[:match]).to be_present
    end

    it 'requires team presence' do
      proposal = MatchProposal.new(match: match, proposed_time: 1.day.from_now)
      expect(proposal).not_to be_valid
      expect(proposal.errors[:team]).to be_present
    end

    it 'requires proposed_time presence' do
      proposal = MatchProposal.new(match: match, team: team1)
      expect(proposal).not_to be_valid
      expect(proposal.errors[:proposed_time]).to be_present
    end

    it 'is valid with all required attributes' do
      proposal = MatchProposal.new(match: match, team: team1, proposed_time: 1.day.from_now)
      expect(proposal).to be_valid
    end
  end

  describe 'scopes' do
    let!(:proposal1) { create(:match_proposal, match: match, team: team1, proposed_time: 1.day.from_now) }
    let!(:other_match) { create(:match, contest: contest) }
    let!(:proposal2) { create(:match_proposal, match: other_match, team: team1, proposed_time: 1.day.from_now) }

    describe '.of_match' do
      it 'returns proposals for specific match' do
        results = MatchProposal.of_match(match)
        expect(results).to include(proposal1)
        expect(results).not_to include(proposal2)
      end
    end

    describe '.confirmed_for_match' do
      let!(:confirmed_proposal) do
        create(:match_proposal, match: match, team: team1,
                                proposed_time: 1.day.from_now, status: MatchProposal::STATUS_CONFIRMED)
      end
      let!(:pending_proposal) do
        create(:match_proposal, match: match, team: team2,
                                proposed_time: 2.days.from_now, status: MatchProposal::STATUS_PENDING)
      end

      it 'returns only confirmed proposals for specific match' do
        results = MatchProposal.confirmed_for_match(match)
        expect(results).to include(confirmed_proposal)
        expect(results).not_to include(pending_proposal)
      end
    end

    describe '.confirmed_upcoming' do
      let!(:confirmed_future) do
        create(:match_proposal, match: match, team: team1,
                                proposed_time: 2.hours.from_now, status: MatchProposal::STATUS_CONFIRMED)
      end
      let!(:confirmed_past) do
        create(:match_proposal, match: other_match, team: team1,
                                proposed_time: 1.hour.ago, status: MatchProposal::STATUS_CONFIRMED)
      end
      let!(:pending_future) do
        create(:match_proposal, match: match, team: team2,
                                proposed_time: 3.hours.from_now, status: MatchProposal::STATUS_PENDING)
      end

      it 'returns only confirmed future proposals' do
        results = MatchProposal.confirmed_upcoming
        expect(results).to include(confirmed_future)
        expect(results).not_to include(confirmed_past)
        expect(results).not_to include(pending_future)
      end
    end

    describe '.confirmed_for_contest' do
      let!(:confirmed_for_contest) do
        create(:match_proposal, match: match, team: team1,
                                proposed_time: 1.day.from_now, status: MatchProposal::STATUS_CONFIRMED)
      end
      let!(:other_contest) { create(:contest) }
      let!(:other_contest_match) { create(:match, contest: other_contest) }
      let!(:confirmed_other_contest) do
        create(:match_proposal, match: other_contest_match, team: team1,
                                proposed_time: 1.day.from_now, status: MatchProposal::STATUS_CONFIRMED)
      end

      it 'returns only confirmed proposals for specific contest' do
        results = MatchProposal.confirmed_for_contest(contest)
        expect(results).to include(confirmed_for_contest)
        expect(results).not_to include(confirmed_other_contest)
      end
    end
  end

  describe '.status_strings' do
    it 'returns hash of status strings' do
      strings = MatchProposal.status_strings
      expect(strings[MatchProposal::STATUS_PENDING]).to eq('Pending')
      expect(strings[MatchProposal::STATUS_REVOKED]).to eq('Revoked')
      expect(strings[MatchProposal::STATUS_REJECTED]).to eq('Rejected')
      expect(strings[MatchProposal::STATUS_CONFIRMED]).to eq('Confirmed')
      expect(strings[MatchProposal::STATUS_DELAYED]).to eq('Delayed')
    end
  end

  describe '#can_create?' do
    let(:proposal) { MatchProposal.new(match: match, team: team1, proposed_time: 1.day.from_now) }

    it 'allows team leaders to create proposals' do
      expect(proposal.can_create?(user1)).to be true
    end

    it 'allows admins to create proposals' do
      admin = create(:user, :admin)
      expect(proposal.can_create?(admin)).to be true
    end

    it 'denies creation to nil user' do
      expect(proposal.can_create?(nil)).to be false
    end

    context 'when match is nil' do
      let(:proposal) { MatchProposal.new(team: team1, proposed_time: 1.day.from_now) }

      it 'denies creation' do
        expect(proposal.can_create?(user1)).to be false
      end
    end
  end

  describe '#can_update?' do
    context 'with nil user' do
      let(:proposal) { create(:match_proposal, match: match, team: team1, proposed_time: 1.day.from_now) }

      it 'denies update' do
        expect(proposal.can_update?(nil)).to be false
      end
    end

    context 'when not changing status' do
      let(:proposal) { create(:match_proposal, match: match, team: team1, proposed_time: 1.day.from_now) }

      it 'allows updates by authorized users' do
        expect(proposal.can_update?(user1)).to be true
      end

      it 'allows updates by admins' do
        admin = create(:user, :admin)
        expect(proposal.can_update?(admin)).to be true
      end
    end

    context 'when changing status' do
      it 'validates status change permissions' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.can_update?(user2, status: MatchProposal::STATUS_CONFIRMED)).to be true
      end
    end
  end

  describe '#can_destroy?' do
    let(:proposal) { MatchProposal.new(match: match, team: team1, proposed_time: 1.day.from_now) }

    it 'requires admin permissions' do
      admin = create(:user, :admin)
      expect(proposal.can_destroy?(admin)).to be true
      expect(proposal.can_destroy?(user1)).to be false
      expect(proposal.can_destroy?(nil)).to be_falsey
    end
  end

  describe '#state_immutable?' do
    let(:proposal) { MatchProposal.new(match: match, team: team1, proposed_time: 1.day.from_now) }

    it 'returns true for rejected status' do
      proposal.status = MatchProposal::STATUS_REJECTED
      expect(proposal.state_immutable?).to be true
    end

    it 'returns true for delayed status' do
      proposal.status = MatchProposal::STATUS_DELAYED
      expect(proposal.state_immutable?).to be true
    end

    it 'returns true for revoked status' do
      proposal.status = MatchProposal::STATUS_REVOKED
      expect(proposal.state_immutable?).to be true
    end

    it 'returns false for pending status' do
      proposal.status = MatchProposal::STATUS_PENDING
      expect(proposal.state_immutable?).to be false
    end

    it 'returns false for confirmed status' do
      proposal.status = MatchProposal::STATUS_CONFIRMED
      expect(proposal.state_immutable?).to be false
    end
  end

  describe '#status_change_allowed?' do
    context 'changing to STATUS_PENDING' do
      let(:proposal) do
        create(:match_proposal, match: match, team: team1,
                                proposed_time: 1.day.from_now, status: MatchProposal::STATUS_CONFIRMED)
      end

      it 'never allows going back to pending' do
        expect(proposal.status_change_allowed?(user1, MatchProposal::STATUS_PENDING)).to be false
        admin = create(:user, :admin)
        expect(proposal.status_change_allowed?(admin, MatchProposal::STATUS_PENDING)).to be false
      end
    end

    context 'changing to STATUS_DELAYED' do
      it 'allows admin to delay confirmed match within time limit' do
        admin = create(:user, :admin)
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 10.minutes.from_now, status: MatchProposal::STATUS_CONFIRMED)
        expect(proposal.status_change_allowed?(admin, MatchProposal::STATUS_DELAYED)).to be true
      end

      it 'denies delay if not confirmed' do
        admin = create(:user, :admin)
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 10.minutes.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(admin, MatchProposal::STATUS_DELAYED)).to be false
      end

      it 'denies delay if not admin' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 10.minutes.from_now, status: MatchProposal::STATUS_CONFIRMED)
        expect(proposal.status_change_allowed?(user1, MatchProposal::STATUS_DELAYED)).to be false
      end

      it 'denies delay if too far in the future' do
        admin = create(:user, :admin)
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_CONFIRMED)
        expect(proposal.status_change_allowed?(admin, MatchProposal::STATUS_DELAYED)).to be false
      end
    end

    context 'changing to STATUS_REVOKED' do
      it 'allows proposing team to revoke pending proposal' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.day.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user1, MatchProposal::STATUS_REVOKED)).to be true
      end

      it 'denies revoke if not proposing team' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.day.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user2, MatchProposal::STATUS_REVOKED)).to be false
      end

      it 'allows revoke of confirmed proposal if beyond confirmation limit' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_CONFIRMED)
        expect(proposal.status_change_allowed?(user1, MatchProposal::STATUS_REVOKED)).to be true
      end

      it 'denies revoke of confirmed proposal within confirmation limit' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 10.minutes.from_now, status: MatchProposal::STATUS_CONFIRMED)
        expect(proposal.status_change_allowed?(user1, MatchProposal::STATUS_REVOKED)).to be false
      end
    end

    context 'changing to STATUS_CONFIRMED' do
      it 'allows opposing team to confirm pending proposal outside time limit' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user2, MatchProposal::STATUS_CONFIRMED)).to be true
      end

      it 'denies confirm if same team' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user1, MatchProposal::STATUS_CONFIRMED)).to be false
      end

      it 'denies confirm if not pending' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_CONFIRMED)
        expect(proposal.status_change_allowed?(user2, MatchProposal::STATUS_CONFIRMED)).to be false
      end

      it 'denies confirm if within confirmation limit' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 10.minutes.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user2, MatchProposal::STATUS_CONFIRMED)).to be false
      end
    end

    context 'changing to STATUS_REJECTED' do
      it 'allows opposing team to reject pending proposal outside time limit' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user2, MatchProposal::STATUS_REJECTED)).to be true
      end

      it 'denies reject if same team' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user1, MatchProposal::STATUS_REJECTED)).to be false
      end

      it 'denies reject if not pending' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_CONFIRMED)
        expect(proposal.status_change_allowed?(user2, MatchProposal::STATUS_REJECTED)).to be false
      end

      it 'denies reject if within confirmation limit' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 10.minutes.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user2, MatchProposal::STATUS_REJECTED)).to be false
      end
    end

    context 'changing to invalid status' do
      it 'denies change to invalid status' do
        proposal = create(:match_proposal, match: match, team: team1,
                                           proposed_time: 1.day.from_now, status: MatchProposal::STATUS_PENDING)
        expect(proposal.status_change_allowed?(user1, 999)).to be false
      end
    end
  end

  describe '.params' do
    it 'permits correct parameters' do
      params = ActionController::Parameters.new(
        match_proposal: {
          status: MatchProposal::STATUS_PENDING,
          match_id: match.id,
          team_id: team1.id,
          proposed_time: Time.now.utc
        }
      )
      permitted = MatchProposal.params(params, user1)
      expect(permitted[:match_id]).to eq(match.id)
      expect(permitted[:team_id]).to eq(team1.id)
      expect(permitted[:status]).to eq(MatchProposal::STATUS_PENDING)
      expect(permitted[:proposed_time]).to be_present
    end

    it 'does not permit unpermitted parameters' do
      params = ActionController::Parameters.new(
        match_proposal: {
          status: MatchProposal::STATUS_PENDING,
          match_id: match.id,
          team_id: team1.id,
          proposed_time: Time.now.utc,
          unauthorized_param: 'should not be permitted'
        }
      )
      permitted = MatchProposal.params(params, user1)
      expect(permitted.key?(:unauthorized_param)).to be false
    end
  end
end
