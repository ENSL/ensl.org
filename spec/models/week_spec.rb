# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Week, type: :model do
  describe 'validations and basics' do
    it 'is valid with contest, map1 and map2 and a name' do
      w = create(:week)
      expect(w).to be_valid
    end

    it 'requires contest, map1 and map2' do
      w = Week.new(name: 'NoRelations')
      w.validate
      expect(w.errors[:contest]).not_to be_empty
      expect(w.errors[:map1]).not_to be_empty
      expect(w.errors[:map2]).not_to be_empty
    end

    it 'requires name length between 1 and 30' do
      w = build(:week, name: '')
      w.validate
      expect(w.errors[:name]).not_to be_empty
    end

    it 'to_s returns name' do
      w = build(:week, name: 'WeekName')
      expect(w.to_s).to eq 'WeekName'
    end
  end

  describe 'scopes and permissions' do
    it 'ordered scope sorts by start_date ascending' do
      create(:week, start_date: Date.today + 2)
      b = create(:week, start_date: Date.today - 2)
      expect(Week.ordered.first).to eq b
    end

    it 'permission helpers require admin' do
      w = build(:week)
      user = double('User')
      allow(user).to receive(:admin?).and_return(false)
      expect(w.can_create?(user)).to be false
      allow(user).to receive(:admin?).and_return(true)
      expect(w.can_create?(user)).to be true
      expect(w.can_update?(user)).to be true
      expect(w.can_destroy?(user)).to be true
    end
  end
end
