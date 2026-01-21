require 'rails_helper'

RSpec.describe 'User login', type: :request do
  let(:username) { 'legacy_md5' }
  let(:raw_password) { 'OldPass123!' }

  def login_post(name, pw)
    post '/users/login', params: { login: { username: name, password: pw } }
  end

  it 'allows MD5 users to log in and upgrades password to scrypt' do
    # create a user and force MD5-stored password
    u = create(:user, username: username)
    u.update_columns(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

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
    u.update_columns(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

    # first login upgrades
    login_post(username, raw_password)
    expect(flash[:notice]).to be_present
    u.reload
    # now login again — should succeed with new format
    login_post(username, raw_password)
    expect(flash[:notice]).to be_present
  end

  it 'does not allow empty password to authenticate or upgrade' do
    u = create(:user, username: 'empty_pw')
    u.update_columns(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

    login_post('empty_pw', '')
    expect(flash[:error]).to be_present
    u.reload
    expect(u.password_hash).to eq(User::PASSWORD_MD5)
  end

  it 'does not authenticate with wrong password and does not upgrade' do
    u = create(:user, username: 'wrong_pw')
    u.update_columns(password_hash: User::PASSWORD_MD5, password: Digest::MD5.hexdigest(raw_password))

    login_post('wrong_pw', 'badpassword')
    expect(flash[:error]).to be_present
    u.reload
    expect(u.password_hash).to eq(User::PASSWORD_MD5)
  end
end
