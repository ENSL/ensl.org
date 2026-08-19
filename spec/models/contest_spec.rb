# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contest, type: :model do
  let(:contest) { create(:contest) }

  describe 'validations' do
    it 'is valid with factory attributes' do
      expect(contest).to be_valid
    end

    it 'requires presence of essential attributes' do
      c = Contest.new
      expect(c).not_to be_valid
      expect(c.errors[:name]).to be_present
      expect(c.errors[:start]).to be_present
      expect(c.errors[:end]).to be_present
      expect(c.errors[:status]).to be_present
      expect(c.errors[:default_time]).to be_present
    end

    it 'rejects invalid status' do
      c = build(:contest, status: 999)
      expect(c).not_to be_valid
      expect(c.errors[:status]).to be_present
    end

    it 'rejects invalid contest_type' do
      c = build(:contest, contest_type: 999)
      expect(c).not_to be_valid
      expect(c.errors[:contest_type]).to be_present
    end
  end

  describe '#to_s and helpers' do
    it 'returns name for to_s' do
      expect(contest.to_s).to eq contest.name
    end
  end

  describe '#elo_score' do
    before do
      # Ensure moduluses and weight are set so elo_score math does not produce NaN or 0
      contest.update!(modulus_even: 10.0, modulus_3to1: 10.0, modulus_4to0: 10.0, modulus_base: 30, weight: 10)
    end

    it 'returns a positive score when first player wins' do
      pos = contest.elo_score(2, 1, 10)
      expect(pos).to be_positive
    end

    it 'returns a negative score when second player wins' do
      neg = contest.elo_score(1, 2, 10)
      expect(neg).to be_negative
    end

    it 'is sensitive to rating difference' do
      small_diff = contest.elo_score(2, 1, 0)
      large_diff = contest.elo_score(2, 1, 100)
      expect(large_diff).to be > small_diff
    end
  end

  describe '#can_join?' do
    it 'denies nil users and users without an eligible team' do
      expect(contest.can_join?(nil)).to be false

      cuser = instance_double(User)
      allow(cuser).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(false)
      allow(cuser).to receive_message_chain(:lead_teams, :not_in_contest, :exists?).and_return(false)

      expect(contest.can_join?(cuser)).to be false
    end

    it 'allows a valid user to join when contest is joinable' do
      cuser = double('user')
      allow(cuser).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(false)
      allow(cuser).to receive_message_chain(:lead_teams, :not_in_contest, :exists?).and_return(true)

      expect(contest.can_join?(cuser)).to be true
    end

    it 'denies banned users' do
      cuser = double('user')
      allow(cuser).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(true)
      allow(cuser).to receive_message_chain(:lead_teams, :not_in_contest, :exists?).and_return(true)

      expect(contest.can_join?(cuser)).to be false
    end

    it 'denies users when contest is not joinable anymore' do
      contest.update!(status: Contest::STATUS_CLOSED)
      cuser = double('user')
      allow(cuser).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(false)
      allow(cuser).to receive_message_chain(:lead_teams, :not_in_contest, :exists?).and_return(true)

      expect(contest.can_join?(cuser)).to be(false)
    end
  end

  describe '#scores_page_state' do
    it 'uses first contester and defaults when optional params are absent' do
      contester = create(:contester, contest: contest)

      state = contest.scores_page_state

      expect(state[:friendly]).to eq(contester)
      expect(state[:modulus_base]).to eq(contest.modulus_base || 30)
      expect(state[:weight]).to eq(contest.weight)
    end

    it 'applies round overrides and explicit weight from params' do
      c1 = create(:contester, contest: contest)
      c2 = create(:contester, contest: contest)
      rounds_param = { '0' => '1.1', '1' => '2.2', '2' => '3.3' }

      state = contest.scores_page_state(friendly_id: c2.id, rounds_param: rounds_param, weight_param: '42.5')

      expect(state[:friendly]).to eq(c2)
      expect(state[:rounds]).to eq([1.1, 2.2, 3.3])
      expect(state[:weight]).to eq(42.5)
      expect(c1).to be_present
    end
  end

  describe '.params' do
    it 'permits expected attributes' do
      params = ActionController::Parameters.new(contest: { name: 'A', status: Contest::STATUS_OPEN })
      permitted = Contest.params(params, nil)
      expect(permitted[:name]).to eq 'A'
      expect(permitted[:status]).to eq Contest::STATUS_OPEN
    end
  end

  describe '.historical' do
    it "returns season and night contests for the 'NS1' key" do
      season = create(:contest, name: 'S1: Opening')
      night = create(:contest, name: 'Nightwatch Cup')
      other = create(:contest, name: 'Random Cup')

      result = Contest.historical('NS1')

      expect(result).to include(season)
      expect(result).to include(night)
      expect(result).not_to include(other)
    end

    it 'filters to contests with an id greater than 113 for any other key' do
      expect(Contest.historical('whatever').to_sql).to include('`id` > 113')
    end
  end

  describe 'association mutation helpers' do
    it 'adds and removes maps by id' do
      map = create(:map)

      expect(contest.add_map_by_id(map.id)).to be true
      expect(contest.maps).to include(map)

      expect(contest.remove_map_by_id(map.id)).to be true
      expect(contest.maps).not_to include(map)
    end

    it 'returns false when map id is missing' do
      expect(contest.add_map_by_id(0)).to be false
      expect(contest.remove_map_by_id(0)).to be false
    end

    it 'does not duplicate a map already attached to the contest' do
      map = create(:map)
      contest.maps << map

      expect do
        contest.add_map_by_id(map.id)
      end.not_to(change { contest.maps.reload.count })
    end
  end

  describe 'ranking helpers and recalculation' do
    it 'updates ladder ranks when a contester moves down or up' do
      ladder = create(:contest, contest_type: Contest::TYPE_LADDER)
      cont1 = create(:contester, contest: ladder, score: 0)
      cont2 = create(:contester, contest: ladder, score: 1)
      cont3 = create(:contester, contest: ladder, score: 2)

      ladder.update_ranks(cont1, 0, 2)
      cont2.reload
      cont3.reload
      expect(cont1.score).to eq(2)
      expect(cont1.trend).to eq(Contester::TREND_DOWN)
      expect([cont2.score, cont3.score]).to eq([0, 1])

      ladder.update_ranks(cont1, 2, 0)
      cont2.reload
      cont3.reload
      expect(cont1.score).to eq(0)
      expect(cont1.trend).to eq(Contester::TREND_UP)
      expect([cont2.score, cont3.score]).to eq([1, 2])
    end

    it 'recalculates contest standings from finished matches' do
      league = create(:contest, :league)
      cont1 = create(:contester, contest: league, score: 99, win: 9, loss: 9, draw: 9)
      cont2 = create(:contester, contest: league, score: 88, win: 8, loss: 8, draw: 8)
      create(:match, contest: league, contester1: cont1, contester2: cont2, score1: 4, score2: 2,
                     match_time: Time.current)

      league.recalculate
      cont1.reload
      cont2.reload

      expect(cont1.score).to eq(4)
      expect(cont2.score).to eq(2)
      expect(cont1.win).to eq(1)
      expect(cont2.loss).to eq(1)
      expect(cont1.draw).to eq(0)
      expect(cont2.draw).to eq(0)
    end
  end
end
