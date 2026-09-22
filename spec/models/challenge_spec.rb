# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Challenge, type: :model do
  describe 'helpers and validations' do
    let(:contest) { create(:contest, default_time: Time.current.change(hour: 20, min: 30), contest_type: Contest::TYPE_LADDER) }
    let(:challenging_user) { create(:user_with_team) }
    let(:challenged_user) { create(:user_with_team) }
    let(:challenging_contester) { create(:contester, team: challenging_user.team, contest: contest, score: 20) }
    let(:challenged_contester) { create(:contester, team: challenged_user.team, contest: contest, score: 10) }
    let(:match_time) { 7.days.from_now.change(hour: 19, min: 0) }

    it 'returns helper values based on mandatory state' do
      voluntary = described_class.new(mandatory: false, match_time: match_time)
      mandatory = described_class.new(mandatory: true, match_time: match_time)

      expect(voluntary.margin).to eq(described_class::CHALLENGE_BEFORE_VOLUNTARY)
      expect(voluntary.autodefault).to eq(match_time - described_class::ACCEPT_BEFORE_VOLUNTARY)

      expect(mandatory.margin).to eq(described_class::CHALLENGE_BEFORE_MANDATORY)
      expect(mandatory.autodefault).to eq(match_time - described_class::ACCEPT_BEFORE_MANDATORY)
    end

    it 'builds defaults for new challenge form data' do
      challenging_contester

      challenge = described_class.build_for_new(user: challenging_user, contester2: challenged_contester)

      expect(challenge.user).to eq(challenging_user)
      expect(challenge.contester2).to eq(challenged_contester)
      expect(challenge.contester1).to eq(challenging_contester)
      expect(challenge.match_time).to be_within(5.seconds).of(2.days.from_now)
    end

    it 'maps commit labels into status values and preserves status for unknown commit labels' do
      challenge = described_class.new(status: described_class::STATUS_PENDING)

      challenge.apply_commit_status('Accept')
      expect(challenge.status).to eq(described_class::STATUS_ACCEPTED)

      challenge.apply_commit_status('Default time')
      expect(challenge.status).to eq(described_class::STATUS_DEFAULT)

      challenge.apply_commit_status('Forfeit')
      expect(challenge.status).to eq(described_class::STATUS_FORFEIT)

      challenge.apply_commit_status('Decline')
      expect(challenge.status).to eq(described_class::STATUS_DECLINED)

      challenge.status = described_class::STATUS_PENDING
      challenge.apply_commit_status('Something else')
      expect(challenge.status).to eq(described_class::STATUS_PENDING)
    end

    it 'skips default_time calculation when contest default time lacks hour support' do
      contest.default_time = nil
      challenge = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                                      match_time: match_time)

      challenge.set_defaults

      expect(challenge.status).to eq(described_class::STATUS_PENDING)
      expect(challenge.default_time).to be_nil
    end

    it 'adds errors for invalid teams and contest state' do
      challenge = described_class.new(contester1: challenging_contester, contester2: challenging_contester,
                                      match_time: match_time)

      challenge.send(:validate_teams)

      expect(challenge.errors[:base]).not_to be_empty

      closed_contest = create(:contest, contest_type: Contest::TYPE_BRACKET, status: Contest::STATUS_OPEN,
                                        end: 1.day.ago)
      closed_cont1 = build(:contester, team: challenging_user.team, contest: closed_contest)
      closed_cont2 = build(:contester, contest: closed_contest)
      closed_cont1.save!(validate: false)
      closed_cont2.save!(validate: false)
      closed_challenge = described_class.new(contester1: closed_cont1, contester2: closed_cont2, match_time: match_time)

      closed_challenge.send(:validate_contest)

      expect(closed_challenge.errors[:base]).not_to be_empty
    end

    it 'adds inactive-contester error when challenger contester is inactive' do
      inactive_cont1 = create(:contester, team: challenging_user.team, contest: contest)
      inactive_cont1.update_column(:active, false)
      challenge = described_class.new(contester1: inactive_cont1, contester2: challenged_contester,
                                      match_time: match_time)

      challenge.send(:validate_teams)

      expect(challenge.errors[:base]).to include(I18n.t(:challenges_inactive))
    end

    it 'rejects non-ladder contests without an attached match' do
      league_contest = create(:contest, contest_type: Contest::TYPE_LEAGUE)
      league_cont1 = create(:contester, team: challenging_user.team, contest: league_contest)
      league_cont2 = create(:contester, team: challenged_user.team, contest: league_contest)
      challenge = described_class.new(contester1: league_cont1, contester2: league_cont2, match_time: match_time)

      challenge.send(:validate_contest)

      expect(challenge.errors[:base]).not_to be_empty
    end

    it 'rejects mandatory challenges for lower-ranked teams' do
      challenge = described_class.new(
        contester1: challenging_contester,
        contester2: challenged_contester,
        match_time: match_time,
        default_time: match_time.end_of_week.change(hour: 20, min: 30),
        mandatory: true
      )

      challenge.send(:validate_mandatory)

      expect(challenge.errors[:base]).not_to be_empty
    end

    it 'adds mandatory conflict errors when pending/default-time constraints already exist' do
      challenge = described_class.new(
        contester1: challenging_contester,
        contester2: challenged_contester,
        match_time: match_time,
        default_time: match_time.end_of_week.change(hour: 20, min: 30),
        mandatory: true
      )

      pending_scope = double('PendingChallengeScope')
      first_where_scope = double('FirstChallengeWhereScope')
      final_where_scope = double('FinalChallengeWhereScope', exists?: true)
      allow(pending_scope).to receive(:where).and_return(first_where_scope)
      allow(first_where_scope).to receive(:where).and_return(final_where_scope)

      match_scope = double('MatchScope')
      allow(Match).to receive(:of_contester).and_return(match_scope)
      allow(match_scope).to receive_messages(
        on_week: double('WeeklyMatchScope', exists?: true),
        around: double('NearbyMatchScope', exists?: true)
      )

      challenge_scope = double('ChallengeScope')
      mandatory_scope = double('MandatoryChallengeScope', on_week: double('WeeklyMandatoryScope', exists?: true))
      allow(described_class).to receive_messages(pending: pending_scope, of_contester: challenge_scope)
      allow(challenge_scope).to receive(:mandatory).and_return(mandatory_scope)

      challenge.send(:validate_mandatory)

      expect(challenge.errors[:base]).to include(I18n.t(:challenges_mandatory_handled))
      expect(challenge.errors[:base]).to include(I18n.t(:challenges_opponent_week))
      expect(challenge.errors[:base]).to include(I18n.t(:challenges_opponent_mandatory_week))
      expect(challenge.errors[:base]).to include(I18n.t(:challenges_opponent_mandatory_week_defaulttime))
      expect(challenge.errors[:base]).to include(I18n.t(:challenges_opponent_defaulttime))
    end

    it 'rejects match times that are too soon and after contest end' do
      contest.update!(end: 2.days.from_now)
      challenge = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                                      match_time: 1.day.from_now, mandatory: true)

      challenge.send(:validate_match_time)

      expect(challenge.errors[:base].size).to be >= 1
    end

    it 'adds contests_end error when requested time is after contest end' do
      contest.update!(end: 1.day.from_now)
      challenge = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                                      match_time: 2.days.from_now)

      challenge.send(:validate_match_time)

      expect(challenge.errors[:base]).to include(I18n.t(:contests_end))
    end

    it 'rejects conflicting pending challenges and matches around the selected time' do
      existing = described_class.new(
        contester1: challenged_contester,
        contester2: challenging_contester,
        match_time: match_time,
        default_time: match_time.end_of_week
      )
      existing.status = described_class::STATUS_PENDING
      existing.save!(validate: false)
      create(
        :match,
        contest: contest,
        contester1: challenged_contester,
        contester2: create(:contester, contest: contest),
        match_time: match_time
      )

      challenge = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                                      match_time: match_time)

      challenge.send(:validate_match_time)

      expect(challenge.errors[:base].size).to eq(2)
    end

    it 'validates optional server availability and official status' do
      unofficial_server = create(:server, official: false)
      unavailable_server = create(:server, official: true)
      allow(unavailable_server).to receive(:is_free).with(match_time).and_return(false)
      allow(unavailable_server).to receive(:is_free).with(match_time.end_of_week.change(hour: 20,
                                                                                        min: 30)).and_return(true)

      unofficial = described_class.new(
        contester1: challenging_contester, contester2: challenged_contester, match_time: match_time,
        default_time: match_time.end_of_week.change(hour: 20, min: 30), server: unofficial_server
      )
      unofficial.send(:validate_server)
      expect(unofficial.errors[:base]).not_to be_empty

      unavailable = described_class.new(
        contester1: challenging_contester, contester2: challenged_contester, match_time: match_time,
        default_time: match_time.end_of_week.change(hour: 20, min: 30), server: unavailable_server
      )
      unavailable.send(:validate_server)
      expect(unavailable.errors[:base]).not_to be_empty
    end

    it 'adds default-time server availability error when specific time is free but default time is not' do
      server = create(:server, official: true)
      default_time = match_time.end_of_week.change(hour: 20, min: 30)
      allow(server).to receive(:is_free).with(match_time).and_return(true)
      allow(server).to receive(:is_free).with(default_time).and_return(false)

      challenge = described_class.new(
        contester1: challenging_contester,
        contester2: challenged_contester,
        match_time: match_time,
        default_time: default_time,
        server: server
      )
      challenge.send(:validate_server)

      expect(challenge.errors[:base]).to include(I18n.t(:servers_notfree_defaulttime))
    end

    it 'validates contest map membership only when maps are present' do
      allowed_map = create(:map)
      contest.maps << allowed_map
      disallowed_map = create(:map)
      challenge = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                                      map1: allowed_map, map2: disallowed_map)

      challenge.send(:validate_map1)
      challenge.send(:validate_map2)

      expect(challenge.errors[:base].size).to eq(1)
    end

    it 'adds map1 validation error when map1 is outside contest map pool' do
      disallowed_map = create(:map)
      challenge = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                                      map1: disallowed_map)

      challenge.send(:validate_map1)

      expect(challenge.errors[:base]).to include(I18n.t(:contests_map_notavailable))
    end

    it 'rejects invalid status changes and non-mandatory status values outside the map' do
      mandatory_challenge = described_class.new(
        contester1: challenging_contester,
        contester2: challenged_contester,
        mandatory: true,
        status: described_class::STATUS_DECLINED
      )

      mandatory_challenge.send(:validate_status)
      expect(mandatory_challenge.errors[:base]).not_to be_empty

      invalid = described_class.new(contester1: challenging_contester, contester2: challenged_contester, status: 99)
      invalid.send(:validate_status)
      expect(invalid.errors[:base]).not_to be_empty
    end

    it 'does not create a match for declined challenges' do
      map = create(:map)
      contest.maps << map
      challenge = described_class.create!(contester1: challenging_contester, contester2: challenged_contester,
                                          match_time: match_time)

      expect do
        challenge.update!(status: described_class::STATUS_DECLINED, map2: map)
      end.not_to change(Match, :count)
    end

    it 'applies permission checks and strong params' do
      challenge = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                                      match_time: match_time)
      banned_user = instance_double(User, admin?: false)
      allow(banned_user).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(true)

      expect(challenge.can_create?(nil)).to be(false)
      expect(challenge.can_create?(banned_user)).to be(false)

      persisted = described_class.create!(contester1: challenging_contester, contester2: challenged_contester,
                                          match_time: match_time)
      expect(persisted.can_update?(challenging_user)).to be(false)
      expect(persisted.can_destroy?(challenged_user)).to be(false)

      params = ActionController::Parameters.new(challenge: { server_id: 5, response: 'ok', ignored: 'x' })
      permitted = described_class.params(params, nil)
      expect(permitted.to_h).to eq('server_id' => 5, 'response' => 'ok')
    end
  end

  describe 'defaults and status transitions' do
    let(:contest) { create(:contest, default_time: Time.now.utc.change(hour: 15, min: 0)) }
    let(:challenging_user) { create(:user_with_team) }
    let(:challenging_team) { challenging_user.team }
    let(:challenged_user) { create(:user_with_team) }
    let(:challenged_team) { challenged_user.team }
    let(:challenging_contester) { create(:contester, team: challenging_team, contest: contest) }
    let(:challenged_contester) { create(:contester, team: challenged_team, contest: contest) }

    it 'sets defaults on create' do
      mt = 3.days.from_now.change(hour: 18)
      ch = described_class.create!(contester1: challenging_contester, contester2: challenged_contester, match_time: mt)
      expect(ch.status).to eq(Challenge::STATUS_PENDING)
      expect(ch.default_time).not_to be_nil
      expect(ch.default_time.hour).to eq(contest.default_time.hour)
    end

    it 'generates a match when accepted' do
      ch = described_class.create!(contester1: challenging_contester, contester2: challenged_contester,
                                   match_time: 2.days.from_now)
      expect(Match.where(challenge: ch)).to be_empty
      ch.update!(status: Challenge::STATUS_ACCEPTED)
      m = Match.find_by(challenge: ch)
      expect(m).not_to be_nil
      expect(m.contester1).to eq(challenging_contester)
      expect(m.contester2).to eq(challenged_contester)
    end

    it 'uses default_time for DEFAULT status' do
      ch = described_class.create!(contester1: challenging_contester, contester2: challenged_contester,
                                   match_time: 2.days.from_now)
      ch.update!(status: Challenge::STATUS_DEFAULT)
      m = Match.find_by(challenge: ch)
      expect(m.match_time.to_i).to eq(ch.default_time.to_i)
    end

    it 'creates a forfeit match with scores' do
      ch = described_class.create!(contester1: challenging_contester, contester2: challenged_contester,
                                   match_time: 2.days.from_now)
      ch.update!(status: Challenge::STATUS_FORFEIT)
      m = Match.find_by(challenge: ch)
      expect(m.forfeit).to be true
      expect(m.score1).to eq(4)
      expect(m.score2).to eq(0)
    end
  end

  describe 'permission helpers' do
    let(:contest) { create(:contest, default_time: Time.now.utc) }
    let(:challenging_user) { create(:user_with_team) }
    let(:challenging_team) { challenging_user.team }
    let(:challenged_user) { create(:user_with_team) }
    let(:challenged_team) { challenged_user.team }
    let(:challenging_contester) { create(:contester, team: challenging_team, contest: contest) }
    let(:challenged_contester) { create(:contester, team: challenged_team, contest: contest) }

    it 'allows leader of contester1 to create' do
      ch = described_class.new(contester1: challenging_contester, contester2: challenged_contester,
                               match_time: 1.day.from_now)
      expect(ch.can_create?(challenging_user)).to be true
    end

    it 'allows leader of contester2 to update when pending' do
      ch = described_class.create!(contester1: challenging_contester, contester2: challenged_contester,
                                   match_time: 1.day.from_now)
      expect(ch.status).to eq(Challenge::STATUS_PENDING)
      expect(ch.can_update?(challenged_user)).to be true
    end

    it 'allows leader of contester1 to destroy when pending' do
      ch = described_class.create!(contester1: challenging_contester, contester2: challenged_contester,
                                   match_time: 1.day.from_now)
      expect(ch.can_destroy?(challenging_user)).to be true
    end
  end
end
