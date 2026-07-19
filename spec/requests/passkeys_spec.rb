# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PasskeysController', type: :request do
  let(:password) { 'PasswordABC123!' }
  let(:user) { create(:user, raw_password: password) }
  let(:session_store) do
    Class.new(Hash) do
      attr_accessor :id

      def enabled?
        true
      end
    end.new
  end

  before do
    session_store.id = 'passkeys-session'
    session_store[:user] = user.id
  end

  describe 'POST /sessions/passkey_options' do
    it 'stores a challenge for the active login session' do
      user.passkey_credentials.create!(external_id: 'credential-1', public_key: 'public-key', sign_count: 0)

      options = Struct.new(:challenge) do
        def as_json(*)
          { challenge: challenge, allowCredentials: [] }
        end
      end.new('challenge-token')

      expect(WebAuthn::Credential).to receive(:options_for_get).with(
        hash_including(
          allow: ['credential-1'],
          user_verification: 'preferred'
        )
      ).and_return(options)

      post '/sessions/passkey_options',
           params: { username: user.username },
           headers: {
             'rack.session' => session_store,
             'rack.session.options' => { id: 'passkeys-session' }
           }

      expect(response).to have_http_status(:ok)
      expect(session[:passkey_login]).to be_present
      expect(session[:passkey_login][:user_id]).to eq(user.id)
    end

    it 'supports discoverable passkey options when username is omitted' do
      user.passkey_credentials.create!(external_id: 'credential-1', public_key: 'public-key', sign_count: 0)

      options = Struct.new(:challenge) do
        def as_json(*)
          { challenge: challenge, allowCredentials: [] }
        end
      end.new('challenge-token')

      expect(WebAuthn::Credential).to receive(:options_for_get).with(
        hash_including(
          allow: [],
          user_verification: 'preferred'
        )
      ).and_return(options)

      post '/sessions/passkey_options',
           params: {},
           headers: {
             'rack.session' => session_store,
             'rack.session.options' => { id: 'passkeys-session' }
           }

      expect(response).to have_http_status(:ok)
      expect(session[:passkey_login]).to be_present
      expect(session[:passkey_login][:user_id]).to be_nil
    end
  end

  describe 'POST /sessions/passkey_authenticate' do
    it 'logs the user in with a verified passkey assertion' do
      user.passkey_credentials.create!(external_id: 'credential-1', public_key: 'public-key', sign_count: 0)

      session_store[:passkey_login] = {
        challenge: 'challenge-token',
        user_id: user.id,
        expires_at: 5.minutes.from_now.to_i
      }

      fake_credential = double('WebAuthn::Credential', id: 'credential-1', sign_count: 1)
      allow(WebAuthn::Credential).to receive(:from_get).and_return(fake_credential)
      allow(fake_credential).to receive(:verify).and_return(true)

      post '/sessions/passkey_authenticate',
           params: {
             credential: {
               id: 'credential-1',
               rawId: 'AQIDBA',
               type: 'public-key',
               response: {
                 authenticatorData: 'BQYH',
                 clientDataJSON: 'CAkK',
                 signature: 'CwwN'
               }
             }
           },
           headers: {
             'rack.session' => session_store,
             'rack.session.options' => { id: 'passkeys-session' }
           }

      expect(response).to have_http_status(:ok)
      expect(session[:user]).to eq(user.id)
      expect(session[:passkey_login]).to be_nil
    end

    it 'authenticates discoverable passkeys without a pre-selected user' do
      user.passkey_credentials.create!(external_id: 'credential-1', public_key: 'public-key', sign_count: 0)

      session_store[:passkey_login] = {
        challenge: 'challenge-token',
        user_id: nil,
        expires_at: 5.minutes.from_now.to_i
      }

      fake_credential = double('WebAuthn::Credential', id: 'credential-1', sign_count: 2)
      allow(WebAuthn::Credential).to receive(:from_get).and_return(fake_credential)
      allow(fake_credential).to receive(:verify).and_return(true)

      post '/sessions/passkey_authenticate',
           params: {
             credential: {
               id: 'credential-1',
               rawId: 'AQIDBA',
               type: 'public-key',
               response: {
                 authenticatorData: 'BQYH',
                 clientDataJSON: 'CAkK',
                 signature: 'CwwN'
               }
             }
           },
           headers: {
             'rack.session' => session_store,
             'rack.session.options' => { id: 'passkeys-session' }
           }

      expect(response).to have_http_status(:ok)
      expect(session[:user]).to eq(user.id)
      expect(session[:passkey_login]).to be_nil
    end
  end

  describe 'POST /users/:id/passkeys/options' do
    it 'prepares registration options for the signed-in account' do
      user.passkey_credentials.create!(external_id: 'credential-1', public_key: 'public-key', sign_count: 0)

      options = Struct.new(:challenge) do
        def as_json(*)
          {
            challenge: challenge,
            rp: { name: 'ENSL' },
            user: { id: 'dXNlci0x', name: 'player', displayName: 'player' }
          }
        end
      end.new('register-challenge')

      expect(WebAuthn::Credential).to receive(:options_for_create).with(
        hash_including(
          exclude: ['credential-1'],
          authenticator_selection: hash_including(
            resident_key: 'required',
            user_verification: 'preferred'
          )
        )
      ).and_return(options)

      post "/users/#{user.id}/passkeys/options",
           headers: {
             'rack.session' => session_store,
             'rack.session.options' => { id: 'passkeys-session' }
           }

      expect(response).to have_http_status(:ok)
      expect(session[:passkey_registration]).to be_present
      expect(session[:passkey_registration][:user_id]).to eq(user.id)
    end
  end

  describe 'POST /users/:id/passkeys' do
    it 'creates a passkey credential after verification' do
      session_store[:passkey_registration] = {
        challenge: 'register-challenge',
        user_id: user.id,
        expires_at: 5.minutes.from_now.to_i
      }

      fake_credential = double('WebAuthn::Credential', id: 'credential-2', public_key: 'public-key-2', sign_count: 7)
      allow(WebAuthn::Credential).to receive(:from_create).and_return(fake_credential)
      allow(fake_credential).to receive(:verify).and_return(true)

      expect do
        post "/users/#{user.id}/passkeys",
             params: {
               credential: {
                 id: 'credential-2',
                 rawId: 'AQIDBA',
                 type: 'public-key',
                 response: {
                   attestationObject: 'BQYH',
                   clientDataJSON: 'CAkK'
                 }
               }
             },
             headers: {
               'rack.session' => session_store,
               'rack.session.options' => { id: 'passkeys-session' }
             }
      end.to change(PasskeyCredential, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(user.reload.passkey_credentials.last.external_id).to eq('credential-2')
    end
  end
end
