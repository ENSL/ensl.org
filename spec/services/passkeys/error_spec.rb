# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Passkeys::Error do
  it 'stores the HTTP status alongside the message' do
    error = described_class.new('boom', status: :unauthorized)

    expect(error.message).to eq('boom')
    expect(error.status).to eq(:unauthorized)
  end
end
