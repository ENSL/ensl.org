# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Passkeys::RegistrationService do
  let(:session) { {} }
  let(:request) { instance_double(ActionDispatch::Request, host: 'ensl.test', base_url: 'https://ensl.test') }
  subject(:service) { described_class.new(session: session, request: request) }

  before do
    allow(Passkeys::Webauthn).to receive(:configure!)
  end

  describe '#options' do
    it 'creates registration options and stores pending state' do
      user = create(:user)
      user.passkey_credentials.create!(external_id: 'cred-existing', public_key: 'pk', sign_count: 0)
      options = instance_double('CreateOptions', challenge: 'register-challenge')

      expect(WebAuthn::Credential).to receive(:options_for_create).with(
        hash_including(
          user: hash_including(name: user.username, display_name: user.username),
          exclude: ['cred-existing'],
          authenticator_selection: hash_including(resident_key: 'required', user_verification: 'preferred')
        )
      ).and_return(options)

      result = service.options(user: user)

      expect(result).to eq(options)
      expect(session[:passkey_registration][:challenge]).to eq('register-challenge')
      expect(session[:passkey_registration][:user_id]).to eq(user.id)
      expect(session[:passkey_registration][:expires_at]).to be > Time.current.to_i
    end

    it 'wraps unexpected option errors as unavailable' do
      user = create(:user)
      allow(WebAuthn::Credential).to receive(:options_for_create).and_raise(StandardError, 'boom')

      expect { service.options(user: user) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unprocessable_content) }
    end
  end

  describe '#create' do
    it 'creates a passkey credential and clears pending session state' do
      user = create(:user)
      session[:passkey_registration] = {
        challenge: 'register-challenge',
        user_id: user.id,
        expires_at: 5.minutes.from_now.to_i
      }

      credential = double('WebAuthnCredential', id: 'cred-1', public_key: 'public-key', sign_count: nil)
      allow(WebAuthn::Credential).to receive(:from_create).and_return(credential)
      allow(credential).to receive(:verify).with('register-challenge').and_return(true)

      expect do
        service.create(user: user, credential_params: { id: 'cred-1' })
      end.to change(PasskeyCredential, :count).by(1)

      expect(user.passkey_credentials.last.external_id).to eq('cred-1')
      expect(user.passkey_credentials.last.sign_count).to eq(0)
      expect(session[:passkey_registration]).to be_nil
    end

    it 'rejects expired or mismatched pending state' do
      user = create(:user)
      session[:passkey_registration] = {
        challenge: 'register-challenge',
        user_id: user.id + 1,
        expires_at: 5.minutes.from_now.to_i
      }

      expect { service.create(user: user, credential_params: {}) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unprocessable_content) }
    end

    it 'returns unauthorized for WebAuthn verification errors' do
      user = create(:user)
      session[:passkey_registration] = {
        challenge: 'register-challenge',
        user_id: user.id,
        expires_at: 5.minutes.from_now.to_i
      }

      credential = double('WebAuthnCredential', id: 'cred-2', public_key: 'pk2', sign_count: 1)
      allow(WebAuthn::Credential).to receive(:from_create).and_return(credential)
      allow(credential).to receive(:verify).and_raise(WebAuthn::Error.new('invalid'))

      expect { service.create(user: user, credential_params: { id: 'cred-2' }) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'returns unavailable when duplicate credential insert occurs' do
      user = create(:user)
      session[:passkey_registration] = {
        challenge: 'register-challenge',
        user_id: user.id,
        expires_at: 5.minutes.from_now.to_i
      }

      credential = double('WebAuthnCredential', id: 'cred-dup', public_key: 'pk', sign_count: 2)
      allow(WebAuthn::Credential).to receive(:from_create).and_return(credential)
      allow(credential).to receive(:verify).and_return(true)
      allow(user.passkey_credentials).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

      expect { service.create(user: user, credential_params: { id: 'cred-dup' }) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unprocessable_content) }
    end
  end
end
