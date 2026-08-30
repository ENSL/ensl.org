# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvalidRecordSummary do
  describe '.call' do
    it 'summarizes invalid rows by model and validation problem' do
      User.new(username: '', email: '', raw_password: '', password: 'x').save!(validate: false)
      Team.new(name: '', tag: '').save!(validate: false)

      summary = described_class.call(model_names: %w[User Team], limit: 10)

      expect(summary[:total_invalid_records]).to eq(2)
      expect(summary[:by_model].keys).to contain_exactly('User', 'Team')
      expect(summary[:by_model]['User'][:invalid_count]).to eq(1)
      expect(summary[:by_model]['Team'][:invalid_count]).to eq(1)
      expect(summary[:by_model]['User'][:top_errors]).to include(a_hash_including(label: a_string_including('username')))
      expect(summary[:by_model]['Team'][:top_errors]).to include(a_hash_including(label: a_string_including('name')))
    end
  end
end
