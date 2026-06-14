require 'rails_helper'

RSpec.describe Extra do
  let(:category) { build(:category) }

  describe '#codings' do
    it 'returns the supported content coding labels' do
      expect(category.codings).to eq(
        Extra::CODING_HTML => 'Plain HTML',
        Extra::CODING_BBCODE => 'BBCode',
        Extra::CODING_MARKDOWN => 'Markdown'
      )
    end
  end

  describe '#check_params' do
    it 'accepts arrays and hashes when all keys are permitted' do
      expect(category.check_params(%w[name sort], %i[name sort])).to be true
      expect(category.check_params({ name: 'Title', sort: 1 }, %i[name sort])).to be true
    end

    it 'rejects keys outside the filter' do
      expect(category.check_params({ bad_key: 'x' }, %i[name sort])).to be false
    end
  end

  describe '#cleanup_string' do
    it 'strips unsupported characters and truncates long strings' do
      expect(category.cleanup_string('ab cd!?-_=+', 6)).to eq('abcd-_')
    end

    it 'returns the cleaned string unchanged when shorter than the limit' do
      expect(category.cleanup_string('Clean_Name-1', 20)).to eq('Clean_Name-1')
    end
  end

  describe '#move_up and #move_down' do
    it 'moves an item up by swapping with the previous record' do
      first = create(:category, sort: 1)
      second = create(:category, sort: 2)
      third = create(:category, sort: 3)
      relation = Category.where(id: [first.id, second.id, third.id])

      second.move_up(relation, 'sort')
      expect(first.reload.sort).to eq(2)
      expect(second.reload.sort).to eq(1)
      expect(third.reload.sort).to eq(3)
    end

    it 'moves an item down by swapping with the next record' do
      first = create(:category, sort: 1)
      second = create(:category, sort: 2)
      third = create(:category, sort: 3)
      relation = Category.where(id: [first.id, second.id, third.id])

      second.move_down(relation, 'sort')
      expect(second.reload.sort).to eq(3)
      expect(third.reload.sort).to eq(2)
      expect(first.reload.sort).to eq(1)
    end

    it 'leaves edge records untouched' do
      first = create(:category, sort: 1)
      second = create(:category, sort: 2)
      third = create(:category, sort: 3)
      relation = Category.where(id: [first.id, second.id, third.id])

      first.move_up(relation, 'sort')
      third.move_down(relation, 'sort')

      expect(first.reload.sort).to eq(1)
      expect(second.reload.sort).to eq(2)
      expect(third.reload.sort).to eq(3)
    end
  end

  describe '#error_messages' do
    it 'returns unique validation messages' do
      invalid_category = build(:category, domain: 99)
      invalid_category.valid?

      expect(invalid_category.error_messages).to eq(invalid_category.errors.full_messages.uniq)
    end
  end
end
