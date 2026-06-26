# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SafeUrl, type: :model do
  describe '.sanitize' do
    it 'allows relative paths' do
      expect(described_class.sanitize('/users?page=2')).to eq('/users?page=2')
    end

    it 'allows http and https urls' do
      expect(described_class.sanitize('http://example.com/path')).to eq('http://example.com/path')
      expect(described_class.sanitize('https://example.com/path')).to eq('https://example.com/path')
    end

    it 'rejects unsafe schemes' do
      expect(described_class.sanitize('javascript:alert(1)')).to eq('#')
    end

    it 'rejects malformed urls' do
      expect(described_class.sanitize('http://[broken')).to eq('#')
    end

    it 'rejects blank values' do
      expect(described_class.sanitize(nil)).to eq('#')
      expect(described_class.sanitize('')).to eq('#')
    end
  end
end
