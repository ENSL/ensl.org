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

  describe '.params' do
    it 'permits current nested profile fields and rejects legacy and protected fields' do
      params = ActionController::Parameters.new(
        user: {
          firstname: 'Jane',
          profile_attributes: { town: 'Oslo', psu: '750W', user_id: 123, signature_parsed: 'injected' }
        }
      )

      permitted = described_class.params(params, user, 'update').to_h

      expect(permitted).to eq(
        'firstname' => 'Jane',
        'profile_attributes' => { 'town' => 'Oslo' }
      )
    end
  end

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
      subject.update!(team_id: team.id)
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

  describe 'agenda matches' do
    let(:team) { create(:team) }
    let(:contest) { create(:contest) }
    let(:team_contester) { create(:contester, team: team, contest: contest) }

    before do
      create(:teamer, user: user, team: team, rank: Teamer::RANK_MEMBER)
    end

    it 'orders upcoming team and referee matches together without duplicates' do
      team_match = create(:match, contest: contest, contester1: team_contester, match_time: 1.day.from_now)
      referee_match = create(:match, referee: user, match_time: 2.days.from_now)
      shared_match = create(
        :match,
        contest: contest,
        contester1: team_contester,
        referee: user,
        match_time: 3.days.from_now
      )
      create(:match, contest: contest, contester1: team_contester, match_time: 1.day.ago)

      expect(user.upcoming_matches).to eq([shared_match, referee_match, team_match])
    end

    it 'includes a match when the users team is the second contester' do
      team_match = create(:match, contest: contest, contester2: team_contester, match_time: 1.day.from_now)

      expect(user.upcoming_matches).to include(team_match)
    end

    it 'excludes team matches when the user is only waiting to join' do
      user.teamers.each { |teamer| teamer.update!(rank: Teamer::RANK_JOINER) }
      team_match = create(:match, contest: contest, contester1: team_contester, match_time: 1.day.from_now)

      expect(user.reload.upcoming_matches).not_to include(team_match)
    end

    it 'excludes upcoming matches for withdrawn contest entries' do
      team_contester.update!(active: false)
      team_match = create(:match, contest: contest, contester1: team_contester, match_time: 1.day.from_now)

      expect(user.upcoming_matches).not_to include(team_match)
    end

    it 'excludes matches for inactive teams and former members' do
      team_match = create(:match, contest: contest, contester1: team_contester, match_time: 1.day.from_now)

      team.update!(active: false)
      expect(user.reload.upcoming_matches).not_to include(team_match)

      team.update!(active: true)
      user.teamers.find_by!(team: team).update!(rank: Teamer::RANK_REMOVED)
      expect(user.reload.upcoming_matches).not_to include(team_match)
    end

    it 'excludes unscheduled matches' do
      unscheduled_team_match = create(:match, contest: contest, contester1: team_contester, match_time: nil)
      unscheduled_referee_match = create(:match, referee: user, match_time: nil)

      expect(user.upcoming_matches).not_to include(unscheduled_team_match, unscheduled_referee_match)
      expect(user.past_matches).not_to include(unscheduled_team_match, unscheduled_referee_match)
    end

    it 'includes only unfinished past matches for team members and referees' do
      team_match = create(:match, contest: contest, contester1: team_contester, match_time: 1.day.ago)
      referee_match = create(:match, referee: user, match_time: 2.days.ago)
      scored_match = create(
        :match,
        :scored,
        contest: contest,
        contester1: team_contester,
        match_time: 3.days.ago
      )

      expect(user.past_matches).to contain_exactly(team_match, referee_match)
      expect(user.past_matches).not_to include(scored_match)
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

      msg = Message.last
      expect(msg.recipient).to eq(u)
      expect(msg.text).to include("Hello #{u.username},")
      expect(msg.text).to include('Your new password is: SecretPass123!')
      expect(msg.text).to include("stored with hash #{u.password_hash_s}")
    end

    it 'send_new_password still resets the password for a record invalid due to unrelated legacy data' do
      # Password reset is system-generated, not raw user input (see generate_password),
      # so it must not be blocked by e.g. a case-insensitive duplicate username.
      create(:user, username: 'DupeReset')
      u = create(:user)
      u.update_column(:username, 'dupereset')

      expect(u.reload).not_to be_valid

      old_password = u.password
      expect { u.send_new_password }.not_to raise_error
      expect(u.reload.password).not_to eq(old_password)
    end

    it '.reset_password_for_identity resets only matching username/email pairs' do
      u = create(:user)
      allow_any_instance_of(User).to receive(:send_new_password).and_return(true)

      expect(User.reset_password_for_identity(username: u.username, email: u.email)).to be true
      expect(User.reset_password_for_identity(username: u.username, email: 'wrong@example.com')).to be false
    end
  end

  describe 'validate_team' do
    it 'rejects assigning a team without a past or present membership' do
      team = create(:team)
      u = build(:user)
      u.team = team

      expect(u.valid?).to be false
      expect(u.team).to eq(team)
      expect(u.errors[:team]).not_to be_empty
    end

    it 'allows assigning an active membership as the primary team' do
      u = create(:user)
      team = create(:team)
      create(:teamer, user: u, team: team, rank: Teamer::RANK_MEMBER)

      expect(u.update(team: team)).to be true
      expect(u.reload.team).to eq(team)
    end

    it 'allows an inactive former team as a profile affiliation but not as an active team' do
      u = create(:user)
      team = create(:team, active: false)
      create(:teamer, user: u, team: team, rank: Teamer::RANK_REMOVED)

      expect(u.update(team: team)).to be true
      expect(u.reload.team).to eq(team)
      expect(u.active_team).to be_nil
    end

    it 'rejects assigning a pending join request as a profile affiliation' do
      u = create(:user)
      team = create(:team)
      create(:teamer, user: u, team: team, rank: Teamer::RANK_JOINER)

      expect(u.update(team: team)).to be false
      expect(u.errors[:team]).not_to be_empty
    end

    it 'rejects changing from a valid primary team to a team without a membership history' do
      u = create(:user)
      current_team = create(:team)
      invalid_team = create(:team)
      create(:teamer, user: u, team: current_team, rank: Teamer::RANK_MEMBER)
      u.update!(team: current_team)

      expect(u.update(team: invalid_team)).to be false
      expect(u.errors[:team]).not_to be_empty
      expect(u.reload.team).to eq(current_team)
    end

    it 'allows unrelated updates when a legacy primary team is invalid' do
      u = create(:user)
      team = create(:team)
      create(:teamer, user: u, team: team, rank: Teamer::RANK_JOINER)
      u.update_column(:team_id, team.id)

      expect(u.update(firstname: 'Updated')).to be true
      expect(u.reload.attributes.slice('firstname', 'team_id')).to eq(
        'firstname' => 'Updated',
        'team_id' => team.id
      )
    end

    it 'allows clearing a legacy invalid primary team' do
      u = create(:user)
      team = create(:team)
      u.update_column(:team_id, team.id)

      expect(u.update(team: nil)).to be true
      expect(u.reload.team_id).to be_nil
    end
  end

  describe '#received_team_messages' do
    it 'includes messages for the active primary team' do
      u = create(:user)
      active_team = create(:team)
      create(:teamer, user: u, team: active_team, rank: Teamer::RANK_MEMBER)
      u.update!(team: active_team)
      message = create(:message, recipient: active_team)

      expect(u.received_team_messages).to contain_exactly(message)
    end

    it 'does not include messages for an inactive former-team affiliation' do
      u = create(:user)
      former_team = create(:team, active: false)
      create(:teamer, user: u, team: former_team, rank: Teamer::RANK_REMOVED)
      u.update!(team: former_team)
      create(:message, recipient: former_team)

      expect(u.reload.team).to eq(former_team)
      expect(u.received_team_messages).to be_empty
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
      legacy_dup.update!(steamid: existing.steamid)
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
            lastname: 'User',
            time_zone: 'Europe/Helsinki'
          }
        )

        built = described_class.build_for_registration(raw_params: raw, actor: nil, remote_ip: '10.9.8.7')
        built.valid?

        expect(built).to be_a(User)
        expect(built).to be_new_record
        expect(built.lastip).to eq('10.9.8.7')
        expect(built.username).to eq('reg_user')
        expect(built.time_zone).to eq('Europe/Helsinki')
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
        subject.steam_registration_profile = { country: 'DE' }

        payload = subject.callback_session_payload

        expect(payload[:verified_steamid]).to eq('0:1:123')
        expect(payload[:cached_user]).to eq(subject.to_json)
        expect(payload[:steam_registration_profile]).to eq(country: 'DE')
      end
    end

    describe '#apply_login_state!' do
      it 'reports password upgrades and links a verified steamid' do
        subject = create(:user, steamid: '0:1:123')
        subject.password_updated = true

        result = subject.apply_login_state!(verified_steamid: '0:1:456')

        expect(result).to eq(banned: false, password_upgraded: true, steamid_updated: true)
        expect(subject.reload.steamid).to eq('0:1:456')
      end

      it 'blocks banned users without mutating their steamid' do
        subject = create(:user, steamid: '0:1:123')
        create(:ban, :site, user: subject)

        result = subject.apply_login_state!(verified_steamid: '0:1:456')

        expect(result).to eq(banned: true, password_upgraded: false, steamid_updated: false)
        expect(subject.reload.steamid).to eq('0:1:123')
      end

      it 'still links a verified steamid when the record is invalid due to unrelated legacy data' do
        # Steam-verified, not typed by the user, so an unrelated legacy problem
        # (a case-insensitive duplicate username here) must not block it.
        create(:user, username: 'DupeSteam')
        subject = create(:user, steamid: '0:1:123')
        subject.update_column(:username, 'dupesteam')

        expect(subject.reload).not_to be_valid

        result = subject.apply_login_state!(verified_steamid: '0:1:456')

        expect(result).to eq(banned: false, password_upgraded: false, steamid_updated: true)
        expect(subject.reload.steamid).to eq('0:1:456')
      end
    end

    describe '#record_login!' do
      it 'stamps lastip and lastvisit even when the record is invalid due to unrelated legacy data' do
        create(:user, username: 'DupeLogin')
        subject = create(:user)
        subject.update_column(:username, 'dupelogin')

        expect(subject.reload).not_to be_valid
        expect(subject.errors[:username]).to include('has already been taken')

        subject.record_login!('203.0.113.9')

        subject.reload
        expect(subject.lastip).to eq('203.0.113.9')
        expect(subject.lastvisit).to be_within(5).of(Time.now.utc)
      end
    end

    describe '#ensure_profile!' do
      # Regression: build_profile on a has_one dependent: :destroy association destroys the
      # existing row on replace. ensure_profile! used to call profile.present? then
      # build_profile, so any stale/false-negative read of that association silently wiped a
      # real profile. It must never be able to destroy an existing row, no matter what.
      it 'never touches an existing profile, even one with real data' do
        subject = create(:user)
        subject.profile.update!(web: 'https://example.com', town: 'Helsinki', signature: 'o7')
        original_profile_id = subject.profile.id

        result = subject.ensure_profile!

        expect(result).to be false
        subject.reload
        expect(subject.profile.id).to eq(original_profile_id)
        expect(subject.profile.web).to eq('https://example.com')
        expect(subject.profile.town).to eq('Helsinki')
        expect(subject.profile.signature).to eq('o7')
      end

      it 'creates a profile when one genuinely does not exist' do
        subject = create(:user)
        subject.profile.destroy

        result = subject.ensure_profile!

        expect(result).to be true
        expect(subject.reload.profile).to be_present
      end

      it 'does not create a second profile when one already exists' do
        subject = create(:user)

        expect { subject.ensure_profile! }.not_to change(Profile, :count)
      end
    end
  end

  describe 'paper trail versioning' do
    it 'tracks updates for username, steamid, lastip, and email' do
      subject = create(:user, username: 'old_name', steamid: '0:1:100', lastip: '1.1.1.1', email: 'old@example.com')

      expect do
        subject.update!(username: 'new_name', steamid: '0:1:101', lastip: '2.2.2.2', email: 'new@example.com')
      end.to change { subject.versions.count }.by(1)

      version = subject.versions.order(:id).last
      reified = version.reify

      expect(version.event).to eq('update')
      expect(reified.username).to eq('old_name')
      expect(reified.steamid).to eq('0:1:100')
      expect(reified.lastip).to eq('1.1.1.1')
      expect(reified.email).to eq('old@example.com')
    end

    it 'finds a historic user by steamid from paper trail records' do
      subject = create(:user, steamid: '0:1:777')
      subject.update!(steamid: '0:1:888')

      expect(User.historic('0:1:777')).to eq(subject)
      expect(User.historic('0:1:888')).to eq(subject)
    end
  end

  describe 'additional branch coverage helpers' do
    it 'returns nil when normalize_steamid receives invalid parsed steam objects' do
      invalid_sid = double('SteamID', valid?: false)
      allow(invalid_sid).to receive(:id).and_return('STEAM_0:1:123')
      allow(SteamID).to receive(:from_string).and_return(invalid_sid)

      expect(User.normalize_steamid('STEAM_0:1:123')).to be_nil
    end

    it 'returns nil when normalized legacy format does not match expected pattern' do
      bad_sid = double('SteamID', valid?: true, id: 'NOT_A_STEAMID')
      allow(SteamID).to receive(:from_string).and_return(bad_sid)

      expect(User.normalize_steamid('steam_weird')).to be_nil
    end

    it 'returns nil avatar_url when user has no profile avatar' do
      subject = create(:user)
      subject.profile.update!(avatar: nil)

      expect(subject.avatar_url).to eq('/images/icons/noavatar.png')
    end

    it 'returns nil steam payload when user has no steamid' do
      subject = create(:user, steamid: nil)

      payload = subject.api_v1_payload

      expect(payload[:steam]).to be_nil
    end

    it 'decrements age when birthday has not yet occurred this year' do
      subject = build(:user, birthdate: Date.new(2000, 12, 31))
      allow(Time.zone).to receive(:today).and_return(Date.new(2026, 1, 1))

      expect(subject.age).to eq(25)
    end

    it 'returns false when touch_last_visit_if_stale! is called for recent visits' do
      subject = create(:user, lastvisit: 30.seconds.ago)

      expect(subject.touch_last_visit_if_stale!).to be(false)
    end

    it 'updates lastvisit when it is older than the given threshold' do
      subject = create(:user, lastvisit: 10.seconds.ago)

      # A near-zero threshold means any past lastvisit counts as stale, so this
      # exercises the update path without having to wait for the real default (2 minutes).
      result = subject.touch_last_visit_if_stale!(threshold: 0.seconds)

      expect(result).to be_truthy
      expect(subject.reload.lastvisit).to be_within(5).of(Time.now.utc)
    end

    it 'leaves lastvisit untouched when it is newer than the given threshold' do
      original = 10.seconds.ago
      subject = create(:user, lastvisit: original)

      result = subject.touch_last_visit_if_stale!(threshold: 1.minute)

      expect(result).to be false
      expect(subject.reload.lastvisit).to be_within(1).of(original)
    end

    it 'still updates lastvisit when the record is invalid due to unrelated legacy data, ' \
       'e.g. a username that now collides case-insensitively' do
      # Production bug: touch_last_visit_if_stale! used `update`, which runs full
      # validation. Any pre-existing legacy data problem unrelated to lastvisit
      # (duplicate username differing only by case, in this case) made the write
      # silently fail forever, no matter how often the user visited the site.
      create(:user, username: 'DupeName')
      subject = create(:user, lastvisit: 10.seconds.ago)
      subject.update_column(:username, 'dupename')

      expect(subject.reload).not_to be_valid
      expect(subject.errors[:username]).to include('has already been taken')

      result = subject.touch_last_visit_if_stale!(threshold: 0.seconds)

      expect(result).to be_truthy
      expect(subject.reload.lastvisit).to be_within(5).of(Time.now.utc)
    end

    it 'still rejects a user trying to rename themselves to an existing case-insensitive duplicate username' do
      # The bypasses above are only for system/bookkeeping writes that don't carry
      # direct user input. A user's own self-service update must still go through
      # full validation, so they can't make a previously-valid record invalid.
      create(:user, username: 'TakenName')
      subject = create(:user, username: 'MyOwnName')

      expect(subject.update(username: 'takenname')).to be false
      expect(subject.errors[:username]).to include('has already been taken')
      expect(subject.reload.username).to eq('MyOwnName')
    end

    it 'gives each newly created user a fresh lastvisit instead of one frozen at class load' do
      # Regression test: `attribute :lastvisit, default: Time.now.utc` evaluates
      # Time.now.utc exactly once (when the class body loads), so every user
      # created afterwards without an explicit lastvisit shared that same
      # frozen timestamp - it never advanced. Create three users at different
      # points in time and prove their default lastvisit values actually
      # differ (and track "now"), instead of all being identical.
      user_a = travel_to(2.days.ago) { create(:user) }
      user_b = travel_to(1.day.ago) { create(:user) }
      user_c = create(:user)

      expect(user_a.lastvisit).to be < user_b.lastvisit
      expect(user_b.lastvisit).to be < user_c.lastvisit
      expect(user_c.lastvisit).to be_within(5).of(Time.now.utc)
    end

    it 'writes can_play flag as 0 in plugin_verified_buffer when user cannot play' do
      subject = create(:user, steamid: '0:1:456')
      allow(subject).to receive(:can_play?).and_return(false)

      buffer = subject.plugin_verified_buffer(channel: 'pub')

      expect(buffer.last).to eq('0')
    end

    it 'does not change password fields when update_password has no eligible source input' do
      subject = build(:user, password_hash: User::PASSWORD_SCRYPT)
      subject.raw_password = nil
      original_hash = subject.password_hash

      subject.update_password

      expect(subject.password_hash).to eq(original_hash)
    end

    it 'still appends a suffix in fix_attributes with no explicit username errors' do
      subject = build(:user, username: "clean_name_#{SecureRandom.hex(4)}")
      original = subject.username

      subject.fix_attributes

      expect(subject.username).to eq("#{original}2")
    end

    it 'returns false for can_change_name? and can_destroy? for non-admin actors' do
      subject = create(:user)
      actor = create(:user)

      expect(subject.can_change_name?(actor)).to be(false)
      expect(subject.can_destroy?(actor)).to be(false)
      expect(subject.can_change_name?(nil)).to be_nil
      expect(subject.can_destroy?(nil)).to be_nil
    end

    it 'returns nil for md5_scrypt users when password mismatches' do
      username = 'md5scrypt_mismatch'
      user = User.new(username: username, email: 'mismatch@example.com')
      user.password_hash = User::PASSWORD_MD5_SCRYPT
      user.password = SCrypt::Password.create(Digest::MD5.hexdigest('goodpass'))
      user.save!(validate: false)

      expect(User.authenticate(username: username, password: 'badpass')).to be_nil
    end

    it 'returns nil for unknown find_for_api format' do
      subject = create(:user)

      expect(User.find_for_api(subject.id, 'unknown')).to be_nil
    end

    it 'returns banned plugin response when server ban is active' do
      ban = instance_double(Ban, expiry: 1.day.from_now, reason: 'abuse')
      allow(Ban).to receive(:active_server_ban_for).with('0:1:555').and_return(ban)

      response = User.plugin_response(steamid: '0:1:555', channel: 'pub')

      expect(response[0]).to eq('#USER#')
      expect(response[1]).to eq('BANNED')
      expect(response[3]).to eq('abuse')
    end

    it 'returns the record from User.get when id is present' do
      subject = create(:user)

      expect(User.get(subject.id)).to eq(subject)
    end

    it 'returns nil from find_or_build without provider or without steam uid' do
      expect(User.find_or_build(nil, '1.1.1.1')).to be_nil
      expect(User.find_or_build({ provider: 'steam' }, '1.1.1.1')).to be_nil
    end

    it 'returns an existing user from find_or_build for known steam uid' do
      subject = create(:user, steamid: '0:1:321')
      auth_hash = { provider: 'steam', uid: 'STEAM_0:1:321', info: { nickname: 'Nick', name: 'Nick Name' } }

      expect(User.find_or_build(auth_hash, '9.9.9.9')).to eq(subject)
    end

    it 'builds a new user from steam auth when steam uid is unknown' do
      auth_hash = {
        provider: 'steam',
        uid: 'STEAM_0:1:654',
        info: {
          nickname: 'FreshNick',
          name: 'Fresh User',
          image: 'https://avatars.steamstatic.com/hash_medium.jpg',
          urls: { Profile: 'https://steamcommunity.com/id/fresh_user/' }
        },
        extra: { raw_info: { loccountrycode: 'de' } }
      }

      result = User.find_or_build(auth_hash, '8.8.8.8')

      expect(result).to be_a(User)
      expect(result).to be_new_record
      expect(result.username).to start_with('FreshNick')
      expect(result.lastip).to eq('8.8.8.8')
      expect(result.steamid).to eq('0:1:654')
      expect(result.country).to eq('DE')
      expect(result.profile).to be_present
      expect(result.profile.steam_profile).to eq('fresh_user')
      expect(result.steam_registration_profile[:avatar_url]).to eq(
        'https://avatars.steamstatic.com/hash_medium.jpg'
      )
    end

    it 'only applies avatar URLs hosted by Steam' do
      subject = build(:user, country: nil)
      profile = subject.build_profile
      allow(profile).to receive(:remote_avatar_url=)

      subject.apply_steam_registration_profile!(
        country: 'GB', steam_profile: 'fresh_user', avatar_url: 'https://example.com/avatar.jpg'
      )

      expect(subject.country).to eq('GB')
      expect(profile.steam_profile).to eq('fresh_user')
      expect(profile).not_to have_received(:remote_avatar_url=)
    end

    it 'accepts string-keyed session metadata without failing when the Steam avatar is unavailable' do
      subject = build(:user, country: nil)
      profile = subject.build_profile
      allow(profile).to receive(:remote_avatar_url=).and_raise(CarrierWave::DownloadError, 'unavailable')

      expect do
        subject.apply_steam_registration_profile!(
          'country' => 'FI',
          'steam_profile' => 'steam_user',
          'avatar_url' => 'https://avatars.steamstatic.com/hash_medium.jpg'
        )
      end.not_to raise_error

      expect(subject.country).to eq('FI')
      expect(profile.steam_profile).to eq('steam_user')
    end
  end
end
