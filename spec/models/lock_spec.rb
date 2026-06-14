require 'rails_helper'

RSpec.describe Lock, type: :model do
  describe 'permissions' do
    let(:lock) { described_class.new(lockable: create(:topic)) }

    it 'allows admins to create and destroy locks' do
      admin = create(:user, :admin)

      expect(lock.can_create?(admin)).to be true
      expect(lock.can_destroy?(admin)).to be true
    end

    it 'blocks non-admin and nil users from create and destroy' do
      user = create(:user)

      expect(lock.can_create?(user)).to be false
      expect(lock.can_create?(nil)).to be_falsey
      expect(lock.can_destroy?(user)).to be false
      expect(lock.can_destroy?(nil)).to be_falsey
    end
  end

  describe '.params' do
    it 'permits the expected lock params' do
      params = ActionController::Parameters.new(lock: { lockable_type: 'Topic', lockable_id: 5, ignored: 'x' })

      permitted = described_class.params(params, nil)

      expect(permitted.to_h).to eq('lockable_type' => 'Topic', 'lockable_id' => 5)
    end
  end
end
