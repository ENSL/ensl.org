# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlienStrategyQuery do
  describe '#canonical_roles' do
    it 'parses both legacy role labels and compact imported strategy paths' do
      query = described_class.new
      legacy = 'r1=gorge+hive,r2=skulk'
      compact = 'gorge+hive,skulk'

      expect(query.send(:canonical_roles, compact)).to eq(query.send(:canonical_roles, legacy))
    end
  end
end
