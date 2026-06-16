require 'rails_helper'

RSpec.describe ImageUploader do
  subject(:uploader) { described_class.new(model) }

  let(:model) { instance_double('ImageOwner', id: 7) }

  describe '#store_dir' do
    it 'stores files in the maps directory' do
      expect(uploader.store_dir).to eq(File.join('local', 'maps'))
    end
  end

  describe '#filename' do
    it 'uses the model id when a file name exists' do
      uploader.instance_variable_set(:@filename, 'screenshot.png')

      expect(uploader.filename).to eq('7.png')
    end

    it 'returns nil when the file name is absent' do
      uploader.instance_variable_set(:@filename, nil)

      expect(uploader.filename).to be_nil
    end
  end

  describe '#extension_white_list' do
    it 'allows common image formats' do
      expect(uploader.extension_white_list).to eq(%w[jpg jpeg gif png])
    end
  end
end
