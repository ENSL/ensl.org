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

    it 'returns a status string' do
      expect(contest.status_s).to be_a String
      expect(contest.statuses[contest.status]).to eq contest.status_s
    end

    it 'returns a default_s starting with a weekday' do
      weekdays_present = Date::DAYNAMES.any? { |d| contest.default_s.include?(d) }
      expect(weekdays_present).to be true
    end
  end

  describe '#elo_score' do
    before do
      # Ensure moduluses and weight are set so elo_score math does not produce NaN or 0
      contest.update!(modulus_even: 10.0, modulus_3to1: 10.0, modulus_4to0: 10.0, modulus_base: 30, weight: 10)
    end

    it 'returns a positive score when first player wins' do
      pos = contest.elo_score(2, 1, 10)
      expect(pos).to be > 0
    end

    it 'returns a negative score when second player wins' do
      neg = contest.elo_score(1, 2, 10)
      expect(neg).to be < 0
    end

    it 'is sensitive to rating difference' do
      small_diff = contest.elo_score(2, 1, 0)
      large_diff = contest.elo_score(2, 1, 100)
      expect(large_diff).to be > small_diff
    end
  end

  describe '#can_join?' do
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
  end

  describe '.params' do
    it 'permits expected attributes' do
      params = ActionController::Parameters.new(contest: { name: 'A', status: Contest::STATUS_OPEN })
      permitted = Contest.params(params, nil)
      expect(permitted[:name]).to eq 'A'
      expect(permitted[:status]).to eq Contest::STATUS_OPEN
    end
  end
end
