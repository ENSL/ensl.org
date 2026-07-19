# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Passkeys::LoginService do
  let(:session) { {} }
  let(:request) { instance_double(ActionDispatch::Request, host: 'ensl.test', base_url: 'https://ensl.test') }
  subject(:service) { described_class.new(session: session, request: request) }

  before do
    allow(Passkeys::Webauthn).to receive(:configure!)
  end

  describe '#challenge' do
    it 'raises unavailable when a username is provided but user has no passkey' do
      user = create(:user)

      expect { service.challenge(username: user.username) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unprocessable_content) }
    end

    it 'creates challenge state for known passkey users' do
      user = create(:user)
      user.passkey_credentials.create!(external_id: 'cred-1', public_key: 'pk', sign_count: 0)
      options = instance_double('GetOptions', challenge: 'challenge-1')
      allow(WebAuthn::Credential).to receive(:options_for_get).and_return(options)

      result = service.challenge(username: user.username)

      expect(result).to eq(options)
      expect(session[:passkey_login][:challenge]).to eq('challenge-1')
      expect(session[:passkey_login][:user_id]).to eq(user.id)
      expect(session[:passkey_login][:expires_at]).to be > Time.current.to_i
    end

    it 'supports discoverable challenge flow when username is blank' do
      options = instance_double('GetOptions', challenge: 'challenge-2')
      expect(WebAuthn::Credential).to receive(:options_for_get)
        .with(hash_including(allow: [], user_verification: 'preferred'))
        .and_return(options)

      service.challenge(username: '')

      expect(session[:passkey_login][:user_id]).to be_nil
    end

    it 'wraps unexpected errors as unavailable' do
      allow(WebAuthn::Credential).to receive(:options_for_get).and_raise(StandardError, 'boom')

      expect { service.challenge(username: nil) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unprocessable_content) }
    end
  end

  describe '#authenticate' do
    it 'rejects missing state' do
      expect { service.authenticate(credential_params: {}) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'rejects expired state' do
      session[:passkey_login] = { challenge: 'c', user_id: nil, expires_at: 1.minute.ago.to_i }

      expect { service.authenticate(credential_params: {}) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'returns invalid when user-scoped credential does not exist' do
      user = create(:user)
      session[:passkey_login] = { challenge: 'c', user_id: user.id, expires_at: 5.minutes.from_now.to_i }
      credential = double('WebAuthnCredential', id: 'missing', sign_count: 3)
      allow(WebAuthn::Credential).to receive(:from_get).and_return(credential)

      expect { service.authenticate(credential_params: { id: 'missing' }) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'authenticates and updates sign_count for discoverable credentials' do
      user = create(:user)
      stored = user.passkey_credentials.create!(external_id: 'cred-2', public_key: 'pk2', sign_count: 1)
      session[:passkey_login] = { challenge: 'challenge-ok', user_id: nil, expires_at: 5.minutes.from_now.to_i }
      credential = double('WebAuthnCredential', id: 'cred-2', sign_count: 7)
      allow(WebAuthn::Credential).to receive(:from_get).and_return(credential)
      allow(credential).to receive(:verify).and_return(true)

      result = service.authenticate(credential_params: { id: 'cred-2' })

      expect(result).to eq(user)
      expect(stored.reload.sign_count).to eq(7)
      expect(session[:passkey_login]).to be_nil
    end

    it 'returns invalid when webauthn verification fails' do
      user = create(:user)
      user.passkey_credentials.create!(external_id: 'cred-3', public_key: 'pk3', sign_count: 1)
      session[:passkey_login] = { challenge: 'challenge', user_id: user.id, expires_at: 5.minutes.from_now.to_i }
      credential = double('WebAuthnCredential', id: 'cred-3', sign_count: 2)
      allow(WebAuthn::Credential).to receive(:from_get).and_return(credential)
      allow(credential).to receive(:verify).and_raise(WebAuthn::Error.new('invalid'))

      expect { service.authenticate(credential_params: { id: 'cred-3' }) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end
  end
end
