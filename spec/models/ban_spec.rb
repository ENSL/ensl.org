# frozen_string_literal: true

# == Schema Information
#
# Table name: bans
#
#  id         :integer          not null, primary key
#  addr       :string(255)
#  ban_type   :integer
#  expiry     :datetime
#  ip         :string(255)
#  reason     :string(255)
#  steamid    :string(255)
#  created_at :datetime
#  updated_at :datetime
#  creator_id :integer
#  server_id  :integer
#  user_id    :integer
#
# Indexes
#
#  index_bans_on_creator_id  (creator_id)
#  index_bans_on_server_id   (server_id)
#  index_bans_on_user_id     (user_id)
#

require 'rails_helper'

describe Ban do
  let!(:user) { create :user }
  let(:ban) { Ban.new }
  let!(:server) { create :server }

  describe '#color' do
    it 'returns red for active bans and green for expired bans' do
      expect(build(:ban, expiry: 1.day.from_now).color).to eq('red')
      expect(build(:ban, :expired).color).to eq('green')
    end
  end

  describe 'validations' do
    it 'accepts supported ban types' do
      valid_ban = build(:ban, ban_type: Ban::TYPE_MUTE)

      valid_ban.valid?

      expect(valid_ban.errors[:ban_type]).to be_empty
    end

    it 'rejects unsupported ban types' do
      invalid_ban = build(:ban, ban_type: 999)

      invalid_ban.valid?

      expect(invalid_ban.errors[:ban_type]).to be_present
    end

    it 'requires a plain IP address for vent bans' do
      vent_ban = build(:ban, ban_type: Ban::TYPE_VENT, ip: '127.0.0.1:27015')

      vent_ban.valid?

      expect(vent_ban.errors[:ip]).to be_present
    end

    it 'accepts vent bans with a valid IP address' do
      vent_ban = build(:ban, ban_type: Ban::TYPE_VENT, ip: '127.0.0.1')

      vent_ban.valid?

      expect(vent_ban.errors[:ip]).to be_empty
    end
  end

  describe '#check_user' do
    it 'assigns user by user_name' do
      ban.user_name = user.username
      ban.check_user

      expect(ban.user).to eq(user)
    end

    it 'assigns user and server if user_name not present' do
      ban.steamid = user.steamid
      ban.addr = server.addr
      ban.check_user

      expect(ban.user).to eq(user)
      expect(ban.server).to eq(server)
    end

    it 'adds an error when a named non-server user cannot be found' do
      ban.user_name = 'missing-user'
      ban.ban_type = Ban::TYPE_SITE

      ban.check_user

      expect(ban.errors[:user_name]).to include('User not found')
    end

    it 'does not add a user_name error for server bans with missing users' do
      ban.user_name = 'missing-user'
      ban.ban_type = Ban::TYPE_SERVER

      ban.check_user

      expect(ban.errors[:user_name]).to be_empty
    end

    it 'adds a base error when neither user nor server can be resolved for non-server bans' do
      ban.steamid = '0:1:9999999'
      ban.addr = '10.0.0.1:27015'
      ban.ban_type = Ban::TYPE_SITE

      ban.check_user

      expect(ban.errors[:base]).to include('User or server must be specified for this ban type')
    end

    it 'allows server bans without a matching user or server record' do
      ban.steamid = '0:1:9999999'
      ban.addr = '10.0.0.1:27015'
      ban.ban_type = Ban::TYPE_SERVER

      ban.check_user

      expect(ban.errors[:base]).to be_empty
    end
  end

  describe 'Permissions' do
    let!(:user) { create :user }
    let!(:admin) { create :user, :admin }
    let!(:server_user) { create :user }
    let(:ban) { Ban.new }

    describe 'can_create?' do
      it 'returns false for nil users' do
        expect(ban.can_create?(nil)).to be_falsey
      end

      it 'returns true for admins' do
        expect(ban.can_create?(admin)).to be_truthy
      end

      it 'returns false for non-admins' do
        expect(ban.can_create?(user)).to be_falsey
      end
    end

    describe 'can_destroy?' do
      it 'returns true for admin' do
        expect(ban.can_destroy?(admin)).to be_truthy
      end

      it 'returns true for the creator when they are allowed to ban' do
        moderator = create(:user, :gather_moderator)
        creator_ban = build(:ban, creator: moderator)

        expect(creator_ban.can_destroy?(moderator)).to be_truthy
      end

      it 'returns false for non-admins' do
        expect(ban.can_destroy?(user)).to be_falsey
      end
    end

    describe 'can_update?' do
      it 'returns true for admin' do
        expect(ban.can_update?(admin)).to be_truthy
      end

      it 'returns true for the creator when they are allowed to ban' do
        moderator = create(:user, :gather_moderator)
        creator_ban = build(:ban, creator: moderator)

        expect(creator_ban.can_update?(moderator)).to be_truthy
      end

      it 'returns false for non-admins' do
        expect(ban.can_update?(user)).to be_falsey
      end
    end
  end
end
