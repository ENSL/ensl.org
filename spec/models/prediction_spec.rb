# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Prediction, type: :model do
  describe '#can_create?' do
    let(:user) { create(:user) }
    let(:match) { create(:match, match_time: 1.day.from_now, score1: nil, score2: nil) }
    let(:prediction) { build(:prediction, match: match, user: user) }

    it 'allows a signed-in user to predict an unplayed future match' do
      expect(prediction.can_create?(user)).to be true
    end

    it 'rejects a missing user and a past match' do
      expect(prediction.can_create?(nil)).to be false

      match.match_time = 1.day.ago
      expect(prediction.can_create?(user)).to be false
    end

    it 'rejects matches with either score entered, including zero' do
      match.score1 = 0
      expect(prediction.can_create?(user)).to be false

      match.score1 = nil
      match.score2 = 0
      expect(prediction.can_create?(user)).to be false
    end

    it 'rejects a second prediction for the same match' do
      create(:prediction, match: match, user: user)

      expect(prediction.can_create?(user)).to be false
    end
  end
end
