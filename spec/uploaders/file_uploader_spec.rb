# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileUploader do
  subject(:uploader) { described_class.new(model) }

  let(:relative_path) { 'unused' }
  let(:model) { instance_double('UploadModel', directory: directory) }
  let(:directory) { instance_double('Directory', relative_path: relative_path) }

  around do |example|
    # This spec manipulates ENV directly to verify Directory.files_root's fallback and override behavior.
    original = ENV['FILES_ROOT']
    ENV.delete('FILES_ROOT')
    example.run
  ensure
    ENV['FILES_ROOT'] = original
  end

  describe '#root' do
    it 'uses the default public files directory when the env var is missing' do
      expect(uploader.root).to eq(Rails.root.join('public/files').to_s)
      expect(ENV['FILES_ROOT']).to eq(Rails.root.join('public/files').to_s)
    end

    it 'reuses an explicit env var value' do
      ENV['FILES_ROOT'] = '/tmp/custom-files'

      expect(uploader.root).to eq('/tmp/custom-files')
    end
  end

  describe '#store_dir' do
    context 'when the model has a directory with a relative path' do
      let(:relative_path) { 'replays/2026' }

      it 'returns the relative path' do
        expect(uploader.store_dir).to eq('replays/2026')
      end
    end

    context 'when the model directory path is empty' do
      let(:relative_path) { '' }

      it 'returns an empty string' do
        expect(uploader.store_dir).to eq('')
      end
    end

    context 'when the model has no directory' do
      let(:directory) { nil }
      let(:relative_path) { nil }

      it 'returns an empty string' do
        expect(uploader.store_dir).to eq('')
      end
    end
  end
end
