# == Schema Information
#
# Table name: users
#
#  id            :integer          not null, primary key
#  birthdate     :date
#  country       :string(255)
#  email         :string(255)
#  firstname     :string(255)
#  lastip        :string(255)
#  lastname      :string(255)
#  lastvisit     :datetime
#  password      :string(255)
#  password_hash :integer          default(0)
#  public_email  :boolean          default(FALSE), not null
#  steamid       :string(255)
#  time_zone     :string(255)
#  username      :string(255)
#  version       :integer
#  created_at    :datetime
#  updated_at    :datetime
#  team_id       :integer
#
# Indexes
#
#  index_users_on_lastvisit  (lastvisit)
#  index_users_on_team_id    (team_id)
#

require 'rails_helper'

describe User do
  let!(:user) { create :user }

  describe '#banned?' do
    it 'returns false if user is not banned' do
      expect(user.banned?).to be_falsey
    end

    it 'returns true if user is banned' do
      Ban.create!(ban_type: Ban::TYPE_SITE,
                  expiry: Time.now.utc + 10.days,
                  user_name: user.username)

      expect(user.banned?).to be_truthy
    end

    it 'returns true for specific bans' do
      Ban.create!(ban_type: Ban::TYPE_MUTE,
                  expiry: Time.now.utc + 10.days,
                  user_name: user.username)

      expect(user.banned?(Ban::TYPE_MUTE)).to be_truthy
    end
  end

  describe '#gather_moderator?' do
    let!(:group) { create :group, :gather_moderator }

    it 'returns true if gather moderator' do
      create :grouper, group: group, user: user
      expect(user.gather_moderator?).to eq(true)
    end
    it 'returns false if not gather moderator' do
      expect(user.gather_moderator?).to eq(false)
    end
  end

  describe 'password and profile behavior' do
    it 'builds and saves profile on create' do
      u = create(:user)
      expect(u.profile).to be_present
      expect(u.profile.user_id).to eq(u.id)
    end

    it 'generate_password produces a raw password and marks random_password' do
      u = build(:user)
      u.generate_password
      expect(u.raw_password).to be_present
      expect(u.raw_password.length).to be >= 8
      expect(u.password_hash).to eq(User::PASSWORD_SCRYPT)
      expect(u.random_password).to be true
    end

    it 'send_new_password saves and creates a Message' do
      u = create(:user)
      u.raw_password = 'SecretPass123!'
      expect { u.send_new_password }.to change { Message.count }.by(1)
      # message should be to this user
      msg = Message.last
      expect(msg.recipient).to eq(u)
    end
  end

  describe 'validate_team' do
    it 'clears invalid team and adds error' do
      team = create(:team)
      u = build(:user)
      u.team = team
      expect(u.valid?).to be false
      expect(u.team).to be_nil
      expect(u.errors[:team]).not_to be_empty
    end
  end

  describe 'authentication and password upgrade' do
    it 'authenticates MD5 password and upgrades to scrypt' do
      username = 'md5user'
      raw = 'letmein123'
      u = User.new(username: username, email: 'md5@example.com')
      u.password_hash = User::PASSWORD_MD5
      u.password = Digest::MD5.hexdigest(raw)
      u.raw_password = nil
      u.save!(validate: false)

      auth = User.authenticate(username: username, password: raw)
      expect(auth).to be_present
      expect(auth).to be_a(User)
      # should have been upgraded to scrypt-based storage
      expect([User::PASSWORD_SCRYPT, User::PASSWORD_MD5_SCRYPT]).to include(auth.password_hash)
    end

    it 'migrates MD5 to MD5_SCRYPT without plaintext, then upgrades on login' do
      username = 'md5wrap'
      raw = 'wizardpw123!'
      u = User.new(username: username, email: 'md5wrap@example.com')
      u.password_hash = User::PASSWORD_MD5
      u.password = Digest::MD5.hexdigest(raw)
      u.raw_password = nil
      u.save!(validate: false)

      # Confirm DB has the MD5 hash stored (no plaintext)
      u_db = User.find_by(username: username)
      expect(u_db).to be_present
      expect(u_db.password_hash).to eq(User::PASSWORD_MD5)
      expect(u_db.password).to eq(Digest::MD5.hexdigest(raw))

      # Simulate migration: wraps existing MD5 hash with scrypt
      u.update_password
      u.save!(validate: false)

      expect(u.password_hash).to eq(User::PASSWORD_MD5_SCRYPT)
      expect(SCrypt::Password.new(u.password)).to eq(Digest::MD5.hexdigest(raw))

      # Login should verify and upgrade to full scrypt(plaintext)
      auth = User.authenticate(username: username, password: raw)
      expect(auth).to be_present
      expect(auth.password_hash).to eq(User::PASSWORD_SCRYPT)
      expect(SCrypt::Password.new(auth.password)).to eq(raw)
    end
  end

  describe 'additional safety checks' do
    it 'returns nil for wrong password' do
      res = User.authenticate(username: user.username, password: 'wrongpassword')
      expect(res).to be_nil
    end

    it 'detects admin, ref, caster, gather_moderator and contributor groups' do
      u1 = create(:user)
      g_admin = create(:group, :admin)
      create(:grouper, user: u1, group: g_admin)
      expect(u1.admin?).to be true

      u2 = create(:user)
      g_ref = create(:group, :ref)
      create(:grouper, user: u2, group: g_ref)
      expect(u2.ref?).to be true

      u3 = create(:user)
      g_gmod = create(:group, :gather_moderator)
      create(:grouper, user: u3, group: g_gmod)
      expect(u3.gather_moderator?).to be true

      u4 = create(:user)
      g_caster = create(:group, :caster)
      create(:grouper, user: u4, group: g_caster)
      expect(u4.caster?).to be true

      u5 = create(:user)
      g_contrib = create(:group, id: Group::CONTRIBUTORS, name: 'Contributors')
      create(:grouper, user: u5, group: g_contrib)
      expect(u5.contributor?).to be true
    end

    it 'corrects steamid universe to 0' do
      u = build(:user, steamid: '1:1:123')
      u.correct_steamid_universe
      expect(u.steamid[0]).to eq('0')
    end

    it 'normalizes SteamID2/3/64 and rejects invalid steamid' do
      # SteamID2 (legacy with prefix)
      u2 = build(:user, steamid: 'STEAM_0:1:123')
      u2.valid?
      expect(u2.errors[:steamid]).to be_empty
      expect(u2.steamid).to eq('0:1:123')

      # SteamID2 without prefix
      u2b = build(:user, steamid: '0:1:123')
      u2b.valid?
      expect(u2b.errors[:steamid]).to be_empty
      expect(u2b.steamid).to eq('0:1:123')

      # SteamID3
      u3 = build(:user, steamid: '[U:1:246]')
      u3.valid?
      expect(u3.errors[:steamid]).to be_empty
      expect(u3.steamid).to eq('0:0:123')

      # SteamID64
      u64 = build(:user, steamid: '76561197960265974')
      u64.valid?
      expect(u64.errors[:steamid]).to be_empty
      expect(u64.steamid).to eq('0:0:123')

      # Invalid
      ubad = build(:user, steamid: 'not-a-steamid')
      ubad.valid?
      expect(ubad.errors[:steamid]).not_to be_empty
    end

    it 'can_play? is true for old users' do
      u = create(:user, created_at: 3.years.ago)
      expect(u.can_play?).to be true
    end

    it 'set_name splits full name into firstname and lastname' do
      u = build(:user)
      u.fullname = 'Alice Smith'
      u.set_name
      expect(u.firstname).to eq('Alice')
      expect(u.lastname).to eq('Smith')
    end

    it 'update_password uses md5 when forced and password_hash is MD5' do
      u = build(:user)
      u.raw_password = 'plainpw'
      u.password_hash = User::PASSWORD_MD5
      u.password_force = true
      u.update_password
      expect(u.password).to eq(Digest::MD5.hexdigest('plainpw'))
    end
  end
end
