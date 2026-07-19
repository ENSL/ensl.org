# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Passkeys::OtpService do
  let(:session) { {} }
  let(:request) { instance_double(ActionDispatch::Request) }
  subject(:service) { described_class.new(session: session, request: request) }

  describe '#challenge' do
    it 'stores a hashed OTP and sends notification' do
      user = create(:user)
      mail = double('MessageDelivery', deliver: true)
      allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(123_456)
      allow(Notifications).to receive(:login_otp).with(user, '123456').and_return(mail)

      service.challenge(user)

      state = session[:pending_login_otp]
      expect(state[:user_id]).to eq(user.id)
      expect(state[:code_digest]).to eq(Digest::SHA256.hexdigest('123456'))
      expect(state[:expires_at]).to be > Time.current.to_i
      expect(mail).to have_received(:deliver)
    end

    it 'raises unprocessable_content when delivery fails' do
      user = create(:user)
      allow(Notifications).to receive(:login_otp).and_raise(StandardError, 'mailer down')

      expect { service.challenge(user) }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unprocessable_content) }
    end
  end

  describe '#verify' do
    it 'rejects missing session state' do
      expect { service.verify(code: '123456') }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'rejects expired OTP state' do
      session[:pending_login_otp] = {
        user_id: create(:user).id,
        code_digest: Digest::SHA256.hexdigest('123456'),
        expires_at: 1.minute.ago.to_i
      }

      expect { service.verify(code: '123456') }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'rejects blank code input' do
      user = create(:user)
      session[:pending_login_otp] = {
        user_id: user.id,
        code_digest: Digest::SHA256.hexdigest('123456'),
        expires_at: 5.minutes.from_now.to_i
      }

      expect { service.verify(code: '   ') }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'rejects invalid code input' do
      user = create(:user)
      session[:pending_login_otp] = {
        user_id: user.id,
        code_digest: Digest::SHA256.hexdigest('123456'),
        expires_at: 5.minutes.from_now.to_i
      }

      expect { service.verify(code: '654321') }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'rejects when user no longer exists' do
      session[:pending_login_otp] = {
        user_id: 999_999,
        code_digest: Digest::SHA256.hexdigest('123456'),
        expires_at: 5.minutes.from_now.to_i
      }

      expect { service.verify(code: '123456') }
        .to raise_error(Passkeys::Error) { |error| expect(error.status).to eq(:unauthorized) }
    end

    it 'returns user and clears state for valid code' do
      user = create(:user)
      session[:pending_login_otp] = {
        user_id: user.id,
        code_digest: Digest::SHA256.hexdigest('123456'),
        expires_at: 5.minutes.from_now.to_i
      }

      result = service.verify(code: '123456')

      expect(result).to eq(user)
      expect(session[:pending_login_otp]).to be_nil
    end
  end

  describe '#clear!' do
    it 'removes pending otp state' do
      session[:pending_login_otp] = { user_id: 1 }

      service.clear!

      expect(session[:pending_login_otp]).to be_nil
    end
  end
end
