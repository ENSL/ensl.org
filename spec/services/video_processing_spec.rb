# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe VideoProcessing, type: :service do
  include Features::VideoSampleHelper

  let(:fixture_name) { 'sample_h264_aac.mp4' }
  let(:input_path) { test_video_path(fixture_name).to_s }
  let(:tmp_output_dir) { Dir.mktmpdir('video_processing_spec') }

  after do
    FileUtils.rm_rf(tmp_output_dir) if tmp_output_dir && Dir.exist?(tmp_output_dir)
  end

  describe '.probe_web_compat' do
    it 'returns structured metadata and compatibility verdict for a real sample file' do
      result = described_class.probe_web_compat(input_path)

      expect(result).to include(:oneliner, :web_friendly, :reasons, :metadata)
      expect(result[:oneliner]).to be_a(String)
      expect(result[:oneliner]).not_to be_empty
      expect(result[:web_friendly]).to eq(true).or eq(false)
      expect(result[:reasons]).to be_an(Array)
      expect(result[:metadata]).to be_a(Hash)

      if result[:web_friendly]
        expect(result[:reasons]).to eq([])
      else
        expect(result[:reasons]).not_to be_empty
      end
    end

    it 'raises InvalidInput when input path does not exist' do
      expect do
        described_class.probe_web_compat('/tmp/does-not-exist-video.mp4')
      end.to raise_error(VideoProcessing::InvalidInput)
    end
  end

  describe '.probe_duration_seconds!' do
    it 'returns duration close to helper-provided expected value for a real sample file' do
      duration = described_class.probe_duration_seconds!(input_path)
      expected_duration = test_video_expected_duration(fixture_name)

      expect(duration).to be > 0
      expect(duration).to be_within(1.0).of(expected_duration)
    end

    it 'raises InvalidInput for missing file' do
      expect do
        described_class.probe_duration_seconds!('/tmp/missing-duration-input.mp4')
      end.to raise_error(VideoProcessing::InvalidInput)
    end
  end

  describe '.random_snapshot!' do
    it 'creates a snapshot image from a real sample file' do
      output_path = File.join(tmp_output_dir, 'snapshot.jpg')

      described_class.random_snapshot!(
        input_path: input_path,
        output_path: output_path,
        seed: 123
      )

      expect(File.exist?(output_path)).to be true
      expect(File.size(output_path)).to be > 0
    end

    it 'raises InvalidInput for missing source file' do
      output_path = File.join(tmp_output_dir, 'snapshot.jpg')

      expect do
        described_class.random_snapshot!(
          input_path: '/tmp/not-there-snapshot-input.mp4',
          output_path: output_path
        )
      end.to raise_error(VideoProcessing::InvalidInput)
    end
  end

  describe '.transcode_for_web!' do
    it 'transcodes a real sample to mp4 and output is web-friendly' do
      output_path = File.join(tmp_output_dir, 'preview.mp4')

      result = described_class.transcode_for_web!(
        input_path: input_path,
        output_path: output_path,
        crf: 22,
        preset: 'veryfast',
        max_width: 1280,
        max_height: 720,
        audio_bitrate: '128k'
      )

      expect(result).to eq(output_path)
      expect(File.exist?(output_path)).to be true
      expect(File.size(output_path)).to be > 0

      compat = described_class.probe_web_compat(output_path)
      expect(compat[:web_friendly]).to be true
      expect(compat[:reasons]).to eq([])
    end

    it 'raises InvalidInput when source file is missing' do
      output_path = File.join(tmp_output_dir, 'preview.mp4')

      expect do
        described_class.transcode_for_web!(
          input_path: '/tmp/not-there-transcode-input.mov',
          output_path: output_path
        )
      end.to raise_error(VideoProcessing::InvalidInput)
    end
  end
end
