# frozen_string_literal: true

# == Schema Information
#
# Table name: forumers
#
#  id         :integer          not null, primary key
#  access     :integer
#  created_at :datetime
#  updated_at :datetime
#  forum_id   :integer
#  group_id   :integer
#
# Indexes
#
#  index_forumers_on_forum_id  (forum_id)
#  index_forumers_on_group_id  (group_id)
#

require 'rails_helper'

describe Forumer do
  describe 'create' do
    let(:forumer) { build :forumer }

    it 'creates a new forumer' do
      expect(forumer.valid?).to eq(true)
      expect do
        forumer.save!
      end.to change(Forumer, :count).by(1)
    end
  end

  describe '.accesses' do
    it 'returns a hash of access levels as a class method' do
      accesses = Forumer.accesses
      expect(accesses).to be_a(Hash)
      expect(accesses.keys).to contain_exactly(
        Forumer::ACCESS_READ,
        Forumer::ACCESS_REPLY,
        Forumer::ACCESS_TOPIC
      )
      expect(accesses.values).to contain_exactly('Read', 'Reply', 'Post a Topic')
    end

    it 'includes READ access with value 0' do
      expect(Forumer.accesses[Forumer::ACCESS_READ]).to eq('Read')
      expect(Forumer::ACCESS_READ).to eq(0)
    end

    it 'includes REPLY access with value 1' do
      expect(Forumer.accesses[Forumer::ACCESS_REPLY]).to eq('Reply')
      expect(Forumer::ACCESS_REPLY).to eq(1)
    end

    it 'includes TOPIC access with value 2' do
      expect(Forumer.accesses[Forumer::ACCESS_TOPIC]).to eq('Post a Topic')
      expect(Forumer::ACCESS_TOPIC).to eq(2)
    end
  end

  describe '#accesses' do
    let(:forumer) { build :forumer }

    it 'returns access levels as an instance method too' do
      accesses = forumer.accesses
      expect(accesses).to be_a(Hash)
      expect(accesses.keys).to contain_exactly(
        Forumer::ACCESS_READ,
        Forumer::ACCESS_REPLY,
        Forumer::ACCESS_TOPIC
      )
    end
  end

  describe 'validations' do
    let(:forum) { create :forum }
    let(:group) { create :group }

    it 'validates uniqueness of group per forum and access level' do
      create(:forumer, forum: forum, group: group, access: Forumer::ACCESS_READ)
      duplicate = build(:forumer, forum: forum, group: group, access: Forumer::ACCESS_READ)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:group_id]).to be_present
    end

    it 'allows same group with different access levels' do
      create(:forumer, forum: forum, group: group, access: Forumer::ACCESS_READ)
      different_access = build(:forumer, forum: forum, group: group, access: Forumer::ACCESS_REPLY)

      expect(different_access).to be_valid
    end

    it 'requires group_id' do
      forumer = build(:forumer, group: nil)
      expect(forumer).not_to be_valid
      expect(forumer.errors[:group_id]).to be_present
    end

    it 'requires forum_id' do
      forumer = build(:forumer, forum: nil)
      expect(forumer).not_to be_valid
      expect(forumer.errors[:forum_id]).to be_present
    end

    it 'validates access is in range 0..2' do
      forumer = build(:forumer, access: -1)
      expect(forumer).not_to be_valid

      forumer.access = 3
      expect(forumer).not_to be_valid

      forumer.access = 0
      expect(forumer).to be_valid

      forumer.access = 2
      expect(forumer).to be_valid
    end
  end
end
