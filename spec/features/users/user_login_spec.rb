# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User login', type: :request do
  let(:username) { 'legacy_md5' }
  let(:raw_password) { 'OldPass123!' }

  def login_post(username, password)
    post '/sessions/login', params: { login: { username: username, password: password } }
  end

  it 'allows MD5 users to log in and upgrades password to scrypt' do
    # create a user and force MD5-stored password
    u = create(:user, username: username)
    u.update!(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

    # login using legacy password
    login_post(username, raw_password)
    expect(flash[:notice]).to be_present

    u.reload
    expect(u.password_hash).not_to eq(User::PASSWORD_MD5)
    expect([User::PASSWORD_SCRYPT, User::PASSWORD_MD5_SCRYPT]).to include(u.password_hash)
    expect(u.lastvisit).to be_within(5).of(Time.now.utc)
  end

  it 'allows login again after upgrade using same raw password' do
    u = create(:user, username: username)
    u.update!(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

    # first login upgrades
    login_post(username, raw_password)
    expect(flash[:notice]).to be_present
    u.reload
    # now login again — should succeed with new format
    login_post(username, raw_password)
    expect(flash[:notice]).to be_present
  end

  it 'still records lastip/lastvisit on login for a user invalid due to unrelated legacy data' do
    # Big-picture regression: production had real users whose accounts were
    # invalid for reasons unrelated to login (e.g. a username that now collides
    # case-insensitively with someone else's after a rename). That must not
    # block ordinary operations like logging in and stamping lastip/lastvisit.
    create(:user, username: 'DupeLoginFlow')
    u = create(:user, username: 'legacy_dupe_login', raw_password: raw_password)
    u.update_column(:username, 'dupeloginflow')
    expect(u.reload).not_to be_valid

    login_post('dupeloginflow', raw_password)

    expect(flash[:notice]).to be_present
    u.reload
    expect(u.lastip).to be_present
    expect(u.lastvisit).to be_within(5).of(Time.now.utc)
  end

  it 'redirects to root if return_to points to an error page' do
    u = create(:user, username: 'return_user', raw_password: raw_password)

    session_store = Class.new(Hash) do
      attr_accessor :id

      def enabled?
        true
      end
    end.new
    session_store.id = 'test-session'
    session_store[:return_to] = '/404'

    post '/sessions/login',
         params: { login: { username: u.username, password: raw_password } },
         headers: {
           'rack.session' => session_store,
           'rack.session.options' => { id: 'test-session' }
         }

    expect(response).to redirect_to('/')
  end

  it 'allows login when user record is invalid due to duplicate username' do
    legacy = User.new(username: 'dup_login', email: 'dup1@example.com')
    legacy.password_hash = User::PASSWORD_MD5
    legacy.password = Digest::MD5.hexdigest(raw_password)
    legacy.raw_password = nil
    legacy.save!(validate: false)

    duplicate = User.new(username: 'dup_login', email: 'dup2@example.com')
    duplicate.password_hash = User::PASSWORD_SCRYPT
    duplicate.password = SCrypt::Password.create('otherpass')
    duplicate.raw_password = nil
    duplicate.save!(validate: false)

    login_post('dup_login', raw_password)
    expect(flash[:notice]).to be_present
    expect(session[:user]).to be_present
  end

  it 'does not allow empty password to authenticate or upgrade' do
    u = create(:user, username: 'empty_pw')
    u.update!(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

    login_post('empty_pw', '')
    expect(flash[:error]).to be_present
    u.reload
    expect(u.password_hash).to eq(User::PASSWORD_MD5)
  end

  it 'does not authenticate with wrong password and does not upgrade' do
    u = create(:user, username: 'wrong_pw')
    u.update!(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

    login_post('wrong_pw', 'badpassword')
    expect(flash[:error]).to be_present
    u.reload
    expect(u.password_hash).to eq(User::PASSWORD_MD5)
  end

  it 'sends a password reset email and internal message when requested' do
    u = create(:user, username: 'reset_me', email: 'reset@example.com')
    ActionMailer::Base.deliveries.clear

    post '/sessions/forgot', params: { username: u.username, email: u.email }
    expect(flash[:notice]).to be_present

    # Mail was enqueued/sent via Notifications.password
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to include(u.email)

    # Check for raw password in email body
    body = mail.body.encoded
    expect(body).to match(/Your new ENSL account password is:/)
    reset_password = body.match(/password is:\s+([^\s<]+)/)[1]
    expect(reset_password.length).to be >= 8

    # Internal message should be created for the user
    expect(Message.where(recipient_type: 'User', recipient_id: u.id).exists?).to be_truthy
  end

  it 'does not send reset email for incorrect info' do
    u = create(:user, username: 'no_email', email: 'nope@example.com')
    ActionMailer::Base.deliveries.clear

    post '/sessions/forgot', params: { username: u.username, email: 'wrong@example.com' }
    expect(flash[:error]).to be_present
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
