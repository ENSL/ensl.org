# frozen_string_literal: true

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

  describe '.normalize_steamid' do
    it 'returns nil for nil and blank values' do
      expect(described_class.normalize_steamid(nil)).to be_nil
      expect(described_class.normalize_steamid('   ')).to be_nil
    end

    it 'accepts legacy values without the STEAM prefix' do
      expect(described_class.normalize_steamid('0:1:125')).to eq('0:1:125')
    end

    it 'returns nil for invalid values' do
      expect(described_class.normalize_steamid('not-a-steamid')).to be_nil
    end
  end

  describe 'simple formatting helpers' do
    it 'splits a full name into first and last names' do
      subject = build(:user)
      subject.fullname = 'Jane Doe'

      subject.set_name

      expect(subject.firstname).to eq('Jane')
      expect(subject.lastname).to eq('Doe')
    end

    it 'stores a single-part fullname as the first name only' do
      subject = build(:user)
      subject.fullname = 'Madonna'
      subject.lastname = nil

      subject.set_name

      expect(subject.firstname).to eq('Madonna')
      expect(subject.lastname).to be_nil
    end

    it 'returns human-readable password hash labels and nil for unknown values' do
      expect(build(:user, password_hash: User::PASSWORD_MD5).password_hash_s).to eq('MD5')
      expect(build(:user, password_hash: User::PASSWORD_SCRYPT).password_hash_s).to eq('Scrypt')
      expect(build(:user, password_hash: User::PASSWORD_MD5_SCRYPT).password_hash_s).to eq('Scrypt+MD5')
      expect(build(:user, password_hash: 99).password_hash_s).to be_nil
    end

    it 'formats email addresses for display' do
      expect(build(:user, email: 'player@example.com').email_s).to eq('player (at) example.com')
    end

    it 'returns Unknown for unmapped countries' do
      expect(build(:user, country: 'ZZ').country_s).to eq('Unknown')
    end

    it 'builds real names from the available name parts' do
      expect(build(:user, firstname: 'Jane', lastname: 'Doe').realname).to eq('Jane Doe')
      expect(build(:user, firstname: 'Jane', lastname: nil).realname).to eq('Jane')
      expect(build(:user, firstname: nil, lastname: 'Doe').realname).to eq('Doe')
      expect(build(:user, firstname: nil, lastname: nil).realname).to eq('')
    end

    it 'includes the town when building the origin string' do
      subject = create(:user, country: 'NO')
      subject.profile.update!(town: 'Oslo')

      expect(subject.from).to include('Oslo')
    end

    it 'falls back to country only when the town is blank' do
      subject = create(:user, country: 'NO')
      subject.profile.update!(town: '')

      expect(subject.from).to eq(subject.country_s)
    end

    it 'returns 0 m when lastvisit is nil and minutes otherwise' do
      expect(build(:user, lastvisit: nil).idle).to eq('0 m')

      recent = build(:user, lastvisit: 5.minutes.ago)
      expect(recent.idle).to match(/\A\d+ m\z/)
    end

    it 'returns the current active teamer when a team is present' do
      subject = create(:user)
      team = create(:team)
      teamer = create(:teamer, user: subject, team: team, rank: Teamer::RANK_MEMBER)
      subject.update_column(:team_id, team.id)
      subject.reload

      expect(subject.current_teamer).to eq(teamer)
    end

    it 'returns nil for current_teamer when no current team is set' do
      expect(build(:user, team: nil).current_teamer).to be_nil
    end

    it 'clears @ensl.org email addresses during preformat but leaves other addresses alone' do
      internal = build(:user, email: 'staff@ensl.org')
      external = build(:user, email: 'staff@example.com')

      internal.preformat
      external.preformat

      expect(internal.email).to eq('')
      expect(external.email).to eq('staff@example.com')
    end

    it 'appends a numeric suffix when fixing duplicate usernames' do
      create(:user, username: 'taken2')
      subject = build(:user, username: 'taken')
      subject.errors.add(:username, 'has already been taken')

      subject.fix_attributes

      expect(subject.username).to eq('taken3')
    end
  end

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

    it 'upgrades MD5 password even if user record is invalid (duplicate username)' do
      username = 'dupuser'
      raw = 'legacyPass123'

      # Create a legacy MD5 user with duplicate username and bypass validations
      legacy = User.new(username: username, email: 'dup1@example.com')
      legacy.password_hash = User::PASSWORD_MD5
      legacy.password = Digest::MD5.hexdigest(raw)
      legacy.raw_password = nil
      legacy.save!(validate: false)

      # Create a duplicate username entry to make legacy record invalid
      dup_user = User.new(username: username, email: 'dup2@example.com')
      dup_user.password_hash = User::PASSWORD_SCRYPT
      dup_user.password = SCrypt::Password.create('otherpass')
      dup_user.raw_password = nil
      dup_user.save!(validate: false)

      auth = nil
      expect do
        auth = User.authenticate(username: username, password: raw)
      end.not_to raise_error

      expect(auth).to be_present
      expect(auth.id).to eq(legacy.id)
      expect([User::PASSWORD_SCRYPT, User::PASSWORD_MD5_SCRYPT]).to include(auth.password_hash)
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
      u2 = build(:user, steamid: 'STEAM_0:1:124')
      u2.valid?
      expect(u2.errors[:steamid]).to be_empty
      expect(u2.steamid).to eq('0:1:124')

      # SteamID2 without prefix
      u2b = build(:user, steamid: '0:1:125')
      u2b.valid?
      expect(u2b.errors[:steamid]).to be_empty
      expect(u2b.steamid).to eq('0:1:125')

      # SteamID3
      u3 = build(:user, steamid: '[U:1:248]')
      u3.valid?
      expect(u3.errors[:steamid]).to be_empty
      expect(u3.steamid).to eq('0:0:124')

      # SteamID64
      u64 = build(:user, steamid: '76561197960265976')
      u64.valid?
      expect(u64.errors[:steamid]).to be_empty
      expect(u64.steamid).to eq('0:0:124')

      # Duplicate steamid is allowed to exist (legacy), but new users cannot take it
      existing = create(:user, steamid: '0:1:123')
      legacy_dup = create(:user)
      legacy_dup.update_column(:steamid, existing.steamid)
      legacy_dup.reload
      legacy_dup.valid?
      expect(legacy_dup.errors[:steamid]).to be_empty

      newcomer = build(:user, steamid: '0:1:123')
      newcomer.valid?
      expect(newcomer.errors[:steamid]).not_to be_empty

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

    describe '#idle' do
      it 'returns 0 m when lastvisit is nil' do
        u = build(:user)
        u.lastvisit = nil
        expect(u.idle).to eq('0 m')
      end

      it 'returns minutes difference rounded down' do
        u = create(:user)
        fixed_now = Time.now.utc
        allow(Time).to receive(:now).and_return(fixed_now)
        u.update!(lastvisit: fixed_now - 125) # 2 minutes 5 seconds ago
        expect(u.idle).to eq('2 m')
      end
    end
  end

  describe 'extracted helper methods' do
    describe '.build_for_registration' do
      it 'builds a user from params and applies remote ip' do
        raw = ActionController::Parameters.new(
          user: {
            username: 'reg_user',
            email: 'reg_user@example.com',
            raw_password: 'Secret123!',
            firstname: 'Reg',
            lastname: 'User'
          }
        )

        built = described_class.build_for_registration(raw_params: raw, actor: nil, remote_ip: '10.9.8.7')

        expect(built).to be_a(User)
        expect(built).to be_new_record
        expect(built.lastip).to eq('10.9.8.7')
        expect(built.username).to eq('reg_user')
      end
    end

    describe '#register_with_preformat' do
      it 'returns true and persists when record is valid' do
        subject = build(:user)

        expect(subject.register_with_preformat).to be true
        expect(subject).to be_persisted
      end

      it 'calls preformat and returns false when record is invalid' do
        subject = build(:user, email: 'not-an-email')
        allow(subject).to receive(:preformat).and_call_original

        expect(subject.register_with_preformat).to be false
        expect(subject).to have_received(:preformat)
      end
    end

    describe '#callback_session_payload' do
      it 'returns verified steamid and cached user json' do
        subject = create(:user, steamid: '0:1:123')

        payload = subject.callback_session_payload

        expect(payload[:verified_steamid]).to eq('0:1:123')
        expect(payload[:cached_user]).to eq(subject.to_json)
      end
    end
  end
end
