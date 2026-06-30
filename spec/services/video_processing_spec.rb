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

      expect(duration).to be_positive
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
      expect(File.size(output_path)).to be_positive
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

    it 'pins the snapshot timestamp to zero when the usable duration window collapses' do
      output_path = File.join(tmp_output_dir, 'snapshot.jpg')

      allow(described_class).to receive(:validate_file!)
      allow(described_class).to receive(:ensure_parent_dir!)
      allow(described_class).to receive(:probe_duration_seconds!).and_return(0.5)
      allow(described_class).to receive(:run_cmd!)

      described_class.random_snapshot!(
        input_path: input_path,
        output_path: output_path,
        avoid_edges_seconds: 1.0
      )

      expect(described_class).to have_received(:run_cmd!).with(
        array_including('-ss', '0.000', output_path),
        'Snapshot extraction failed',
        capture: true
      )
    end

    it 'uses a non-seeded random generator when no seed is provided' do
      output_path = File.join(tmp_output_dir, 'snapshot.jpg')
      random = instance_double(Random, rand: 0.25)

      allow(described_class).to receive(:validate_file!)
      allow(described_class).to receive(:ensure_parent_dir!)
      allow(described_class).to receive(:probe_duration_seconds!).and_return(10.0)
      allow(described_class).to receive(:run_cmd!)
      allow(Random).to receive(:new).with(no_args).and_return(random)

      described_class.random_snapshot!(
        input_path: input_path,
        output_path: output_path,
        avoid_edges_seconds: 2.0
      )

      expect(Random).to have_received(:new).with(no_args)
      expect(described_class).to have_received(:run_cmd!).with(
        array_including('-ss', '3.500', output_path),
        'Snapshot extraction failed',
        capture: true
      )
    end

    it 'uses the explicit timestamp when one is provided' do
      output_path = File.join(tmp_output_dir, 'snapshot.jpg')

      allow(described_class).to receive(:validate_file!)
      allow(described_class).to receive(:ensure_parent_dir!)
      allow(described_class).to receive(:probe_duration_seconds!).and_return(10.0)
      allow(described_class).to receive(:run_cmd!)

      described_class.random_snapshot!(
        input_path: input_path,
        output_path: output_path,
        at_seconds: 8.5
      )

      expect(described_class).to have_received(:run_cmd!).with(
        array_including('-ss', '8.500', output_path),
        'Snapshot extraction failed',
        capture: true
      )
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
      expect(File.size(output_path)).to be_positive

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

    it 'passes through the requested fps override when present' do
      output_path = File.join(tmp_output_dir, 'preview.mp4')

      allow(described_class).to receive(:validate_file!)
      allow(described_class).to receive(:ensure_parent_dir!)
      allow(described_class).to receive(:run_cmd!)

      result = described_class.transcode_for_web!(
        input_path: input_path,
        output_path: output_path,
        fps: 24
      )

      expect(result).to eq(output_path)
      expect(described_class).to have_received(:run_cmd!).with(
        array_including('-r', '24', output_path),
        'Transcoding failed'
      )
    end
  end

  describe '.probe_duration_seconds!' do
    it 'raises CommandFailed when ffprobe omits duration' do
      allow(described_class).to receive(:video_metadata).and_return({ 'format' => {} })

      expect do
        described_class.probe_duration_seconds!(input_path)
      end.to raise_error(VideoProcessing::CommandFailed, /Could not read duration/)
    end
  end

  describe '.video_info_oneliner' do
    it 'falls back to placeholders when metadata is sparse' do
      meta = {
        'format' => { 'format_name' => 'matroska' },
        'streams' => []
      }

      allow(described_class).to receive(:video_metadata).and_return(meta)

      oneliner, returned_meta = described_class.send(:video_info_oneliner, input_path)

      expect(oneliner).to include('container=matroska')
      expect(oneliner).to include('duration=?')
      expect(oneliner).to include('video=none')
      expect(oneliner).to include('audio=none')
      expect(oneliner).not_to include('bitrate=')
      expect(returned_meta).to eq(meta)
    end

    it 'formats hour-long durations and omits optional fields when missing' do
      meta = {
        'format' => {
          'format_name' => 'mp4',
          'duration' => '3661.5'
        },
        'streams' => [
          {
            'codec_type' => 'video',
            'codec_name' => 'h264',
            'avg_frame_rate' => '30'
          },
          {
            'codec_type' => 'audio',
            'codec_name' => 'aac'
          }
        ]
      }

      allow(described_class).to receive(:video_metadata).and_return(meta)

      oneliner, = described_class.send(:video_info_oneliner, input_path)

      expect(oneliner).to include('duration=1:01:01.50')
      expect(oneliner).to include('video=h264')
      expect(oneliner).to include('audio=aac')
      expect(oneliner).not_to include('fps=')
      expect(oneliner).not_to include('res=')
      expect(oneliner).not_to include('pix_fmt=')
      expect(oneliner).not_to include('sr=')
      expect(oneliner).not_to include('ch=')
    end

    it 'formats bitrate, fps, and full stream details when present' do
      meta = {
        'format' => {
          'format_name' => 'mp4,mov',
          'duration' => '61.25',
          'bit_rate' => '1250000'
        },
        'streams' => [
          {
            'codec_type' => 'video',
            'codec_name' => 'h264',
            'codec_tag_string' => 'avc1',
            'width' => 1920,
            'height' => 1080,
            'pix_fmt' => 'yuv420p',
            'avg_frame_rate' => '30000/0'
          },
          {
            'codec_type' => 'audio',
            'codec_name' => 'aac',
            'sample_rate' => '48000',
            'channels' => 2
          }
        ]
      }

      allow(described_class).to receive(:video_metadata).and_return(meta)

      oneliner, = described_class.send(:video_info_oneliner, input_path)

      expect(oneliner).to include('bitrate=1250kbps')
      expect(oneliner).to include('video=h264(avc1)')
      expect(oneliner).to include('res=1920x1080')
      expect(oneliner).to include('pix_fmt=yuv420p')
      expect(oneliner).to include('sr=48000Hz')
      expect(oneliner).to include('ch=2')
      expect(oneliner).not_to include('fps=')
    end
  end

  describe '.web_friendly?' do
    it 'reports missing video and audio streams' do
      ok, reasons = described_class.send(:web_friendly?, {
                                           'format' => { 'format_name' => 'matroska' },
                                           'streams' => []
                                         })

      expect(ok).to be(false)
      expect(reasons).to include(%r{Container is not MP4/ISO BMFF}.match?(reasons.first) ? reasons.first : a_string_matching(%r{Container is not MP4/ISO BMFF}))
      expect(reasons).to include('No video stream found')
      expect(reasons).to include('No audio stream (OK for silent video, but some UX expects audio)')
    end

    it 'reports codec, tag, and pixel format mismatches' do
      ok, reasons = described_class.send(:web_friendly?, {
                                           'format' => { 'format_name' => 'avi' },
                                           'streams' => [
                                             {
                                               'codec_type' => 'video',
                                               'codec_name' => 'vp9',
                                               'codec_tag_string' => 'vp09',
                                               'pix_fmt' => 'yuv422p'
                                             },
                                             {
                                               'codec_type' => 'audio',
                                               'codec_name' => 'mp3'
                                             }
                                           ]
                                         })

      expect(ok).to be(false)
      expect(reasons).to include(a_string_matching(/Video codec is not H\.264/))
      expect(reasons).to include(a_string_matching(/Video codec tag is not avc1/))
      expect(reasons).to include(a_string_matching(/Pixel format not yuv420p/))
      expect(reasons).to include(a_string_matching(/Audio codec is not AAC/))
    end
  end

  describe '.video_metadata' do
    it 'wraps JSON parse failures from ffprobe output' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(input_path).and_return(true)
      allow(described_class).to receive(:run_cmd!).and_return('not json')

      expect do
        described_class.send(:video_metadata, input_path)
      end.to raise_error(VideoProcessing::CommandFailed, /invalid JSON/)
    end
  end

  describe '.run_cmd!' do
    it 'raises a concise error when a command fails without stdout or stderr' do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(['', '', status])

      expect do
        described_class.send(:run_cmd!, %w[ffprobe sample.mp4], 'ffprobe failed')
      end.to raise_error(VideoProcessing::CommandFailed, /ffprobe failed\.\nCommand: ffprobe sample\.mp4\n\z/)
    end

    it 'includes stdout and stderr when a command fails noisily' do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(['progress output', 'fatal error', status])

      expect do
        described_class.send(:run_cmd!, %w[ffprobe sample.mp4], 'ffprobe failed')
      end.to raise_error(
        VideoProcessing::CommandFailed,
        /STDERR:\nfatal error\nSTDOUT:\nprogress output/
      )
    end
  end

  describe '.validate_file!' do
    it 'raises InvalidInput when the file is unreadable' do
      Tempfile.create('video_processing_unreadable') do |file|
        File.chmod(0o000, file.path)

        expect do
          described_class.send(:validate_file!, file.path)
        end.to raise_error(VideoProcessing::InvalidInput, /not readable/)
      ensure
        File.chmod(0o644, file.path)
      end
    end
  end
end
