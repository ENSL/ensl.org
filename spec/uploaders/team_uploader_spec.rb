# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamUploader do
  subject(:uploader) { described_class.new }

  describe '#store_dir' do
    it 'stores files in the logos directory' do
      expect(uploader.store_dir).to eq(File.join('local', 'logos'))
    end
  end

  describe '#default_url' do
    it 'returns the team logo fallback image' do
      expect(uploader.default_url).to eq('/images/icons/noavatar.png')
    end
  end
end
