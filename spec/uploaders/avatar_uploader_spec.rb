# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AvatarUploader do
  subject(:uploader) { described_class.new(model) }

  let(:model) { instance_double('User', id: 42) }

  describe '#store_dir' do
    it 'stores files in the avatars directory' do
      expect(uploader.store_dir).to eq(File.join('local', 'avatars'))
    end
  end

  describe '#default_url' do
    it 'returns the avatar fallback image' do
      expect(uploader.default_url).to eq('/images/icons/noavatar.png')
    end
  end

  describe '#filename' do
    it 'uses the model id and keeps the extension' do
      uploader.instance_variable_set(:@filename, 'profile.jpeg')

      expect(uploader.filename).to eq('42.jpeg')
    end

    it 'returns nil when no file name is present' do
      uploader.instance_variable_set(:@filename, nil)

      expect(uploader.filename).to be_nil
    end
  end
end
