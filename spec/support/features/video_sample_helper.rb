# frozen_string_literal: true

require 'open3'
require 'shellwords'
require 'net/http'
require 'uri'

module Features
  module VideoSampleHelper
    # Configuration for test video samples
    TEST_VIDEOS_DIR = Pathname.new(ENV.fetch('TEST_VIDEOS_DIR',
                                             Rails.root.join('spec/fixtures/files/videos').to_s)).freeze
    TEST_VIDEO_URL = ENV['TEST_VIDEO_URL'].to_s.strip.freeze
    TEST_VIDEO_FILENAME = ENV.fetch('TEST_VIDEO_FILENAME', 'test_video.mp4').to_s.strip.freeze

    REMOTE_VIDEO_LIST = [
      'AtomicNS.mp4',
      'nancy.wmv',
      'edrushdoesit.avi'
    ].freeze

    GENERATED_VIDEO_SPECS = [
      {
        filename: 'sample_h264_aac.mp4',
        duration: 6.0,
        args: ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '128k']
      },
      {
        filename: 'sample_vp9_opus.webm',
        duration: 6.0,
        args: ['-c:v', 'libvpx-vp9', '-b:v', '1M', '-c:a', 'libopus', '-b:a', '96k']
      },
      {
        filename: 'sample_mpeg4_mp3.avi',
        duration: 6.0,
        args: ['-c:v', 'mpeg4', '-q:v', '5', '-c:a', 'libmp3lame', '-b:a', '128k']
      },
      {
        filename: 'sample_h264_aac.mkv',
        duration: 6.0,
        args: ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '128k']
      }
    ].freeze

    # Maximum sample duration (in seconds) to extract from each video
    MAX_SAMPLE_DURATION = 15
    CIRCLECI_DEFAULT_MAX_VIDEO_INPUT_BYTES = 4 * 1024 * 1024

    def running_on_circleci?
      ENV['CIRCLECI'].to_s == 'true'
    end

    def circleci_max_video_input_bytes
      raw = ENV['CIRCLECI_MAX_VIDEO_INPUT_BYTES'].to_s.strip
      return CIRCLECI_DEFAULT_MAX_VIDEO_INPUT_BYTES if raw.empty?

      Integer(raw)
    rescue ArgumentError, TypeError
      CIRCLECI_DEFAULT_MAX_VIDEO_INPUT_BYTES
    end

    def ffmpeg_bin
      ENV.fetch('FFMPEG_BIN', 'ffmpeg')
    end

    def ffprobe_bin
      ENV.fetch('FFPROBE_BIN', 'ffprobe')
    end

    def command_available?(command)
      system('sh', '-lc', "command -v #{Shellwords.escape(command)} >/dev/null 2>&1")
    end

    def skip_video_specs!(reason)
      return skip(reason) if respond_to?(:skip)

      raise reason
    end

    def ensure_video_tooling_for_circleci!
      return unless running_on_circleci?

      missing = []
      missing << ffmpeg_bin unless command_available?(ffmpeg_bin)
      missing << ffprobe_bin unless command_available?(ffprobe_bin)
      return if missing.empty?

      skip_video_specs!("Skipping video specs on CircleCI: missing #{missing.join(', ')}")
    end

    # Ensure test videos are available, downloading if necessary
    # This method is safe to call multiple times
    def ensure_test_videos
      ensure_video_tooling_for_circleci!

      FileUtils.mkdir_p(TEST_VIDEOS_DIR)

      GENERATED_VIDEO_SPECS.each do |spec|
        local_path = TEST_VIDEOS_DIR.join(spec[:filename])
        next if File.exist?(local_path)

        generate_video_fixture(spec, local_path)
      end

      if TEST_VIDEO_URL.present?
        local_path = TEST_VIDEOS_DIR.join(TEST_VIDEO_FILENAME)
        unless File.exist?(local_path)
          download_and_sample_video(TEST_VIDEO_FILENAME, local_path,
                                    remote_url: TEST_VIDEO_URL)
        end
        return
      end

      return if running_on_circleci?

      REMOTE_VIDEO_LIST.each do |filename|
        local_path = TEST_VIDEOS_DIR.join(filename)
        next if File.exist?(local_path)

        download_and_sample_video(filename, local_path)
      end
    end

    # Download a single video from production domain and create a sample
    def download_and_sample_video(filename, local_path, remote_url: nil)
      production_domain = ENV['PRODUCTION_DOMAIN'] || 'https://www.ensl.org'
      production_domain = "https://#{production_domain}" unless production_domain.to_s.match?(%r{\Ahttps?://}i)
      remote_url ||= "#{production_domain}/files/videos/#{filename}"

      temp_full_path = TEST_VIDEOS_DIR.join("temp_#{filename}")

      # Allow network access for this specific download
      # WebMock will be disabled for this request
      Rails.logger.info("Downloading test video from #{remote_url}")

      begin
        return unless download_file(remote_url, temp_full_path)

        # Create a 15-second sample using ffmpeg
        create_video_sample(temp_full_path, local_path, MAX_SAMPLE_DURATION)

        Rails.logger.info("Created video sample: #{local_path}")
      ensure
        # Clean up temporary full file
        FileUtils.rm_f(temp_full_path) if File.exist?(temp_full_path)
      end
    end

    # Download a file from URL to local path
    # Bypasses WebMock restriction for this specific request
    def download_file(url, destination)
      # Temporarily allow this specific host
      uri = URI.parse(url)

      # If WebMock is loaded, allow this specific request
      WebMock.disable_net_connect!(allow_localhost: true, allow: uri.host) if defined?(WebMock)

      begin
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.open_timeout = 20
          http.read_timeout = 120
          http.get(uri.request_uri)
        end

        raise "Unexpected response: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        File.open(destination, 'wb') do |local_file|
          local_file.write(response.body)
        end
        true
      rescue StandardError => e
        Rails.logger.warn("Could not download #{url}: #{e.message}. Skipping remote sample.")
        false
      ensure
        # Restore WebMock restrictions
        WebMock.disable_net_connect!(allow_localhost: true) if defined?(WebMock)
      end
    end

    def generate_video_fixture(spec, output_path)
      ffmpeg = ffmpeg_bin

      cmd = [
        ffmpeg,
        '-y',
        '-f', 'lavfi',
        '-i', "testsrc2=size=1280x720:rate=30:duration=#{spec[:duration]}",
        '-f', 'lavfi',
        '-i', 'sine=frequency=1000:sample_rate=48000:duration=6',
        '-shortest'
      ]

      cmd.concat(spec[:args])
      cmd << output_path.to_s

      _stdout, stderr, status = Open3.capture3(*cmd)
      return if status.success?

      Rails.logger.warn("Could not generate #{spec[:filename]}: #{stderr}. Skipping generated sample.")
    end

    # Create a sample (first N seconds) from a video file using ffmpeg
    def create_video_sample(input_path, output_path, duration_seconds)
      return unless File.exist?(input_path)

      ffmpeg = ffmpeg_bin

      cmd = [
        ffmpeg,
        '-y', # Overwrite output file
        '-i', input_path.to_s,
        '-t', duration_seconds.to_s, # Duration
        '-c', 'copy', # Copy codec (fast, no re-encoding)
        output_path.to_s
      ]

      _stdout_str, stderr_str, status = Open3.capture3(*cmd)

      return if status.success?

      Rails.logger.error("ffmpeg failed: #{stderr_str}")
      # Fallback: just copy the first duration using re-encoding
      cmd = [
        ffmpeg,
        '-y',
        '-i', input_path.to_s,
        '-t', duration_seconds.to_s,
        '-c:v', 'libx264',
        '-c:a', 'aac',
        output_path.to_s
      ]
      system(*cmd)
    end

    # Create a minimal test video file using ffmpeg
    # This is a fallback when downloads fail
    def create_minimal_test_video(output_path)
      ffmpeg = ffmpeg_bin

      # Create a 5-second black video with silent audio
      cmd = [
        ffmpeg,
        '-y',
        '-f', 'lavfi',
        '-i', 'color=c=black:s=640x480:d=5',
        '-f', 'lavfi',
        '-i', 'anullsrc=r=44100:cl=stereo',
        '-t', '5',
        '-c:v', 'libx264',
        '-c:a', 'aac',
        output_path.to_s
      ]

      system(*cmd)

      return if File.exist?(output_path)

      # Last resort: create a dummy file
      FileUtils.touch(output_path)
    end

    def all_video_specs
      generated = GENERATED_VIDEO_SPECS.map { |s| { filename: s[:filename], expected_duration: s[:duration] } }
      remote = REMOTE_VIDEO_LIST.map { |name| { filename: name, expected_duration: MAX_SAMPLE_DURATION.to_f } }
      if TEST_VIDEO_URL.present?
        remote << { filename: TEST_VIDEO_FILENAME,
                    expected_duration: MAX_SAMPLE_DURATION.to_f }
      end
      generated + remote
    end

    def available_video_specs
      ensure_test_videos

      specs = all_video_specs.select { |spec| File.exist?(TEST_VIDEOS_DIR.join(spec[:filename])) }
      return specs unless running_on_circleci?

      max_bytes = circleci_max_video_input_bytes
      capped_specs = specs.select { |spec| File.size(TEST_VIDEOS_DIR.join(spec[:filename])) <= max_bytes }
      return capped_specs unless capped_specs.empty?

      skip_video_specs!("Skipping video specs on CircleCI: no fixture within #{max_bytes} bytes")
    end

    # Get path to a test video file by index or filename
    def test_video_path(identifier = 0)
      specs = available_video_specs
      raise 'No test videos available' if specs.empty?

      selected = if identifier.is_a?(Integer)
                   specs[identifier] || specs.first
                 else
                   specs.find { |s| s[:filename] == identifier.to_s } || specs.first
                 end

      TEST_VIDEOS_DIR.join(selected[:filename])
    end

    def test_video_expected_duration(identifier = 0)
      specs = available_video_specs
      raise 'No test videos available' if specs.empty?

      selected = if identifier.is_a?(Integer)
                   specs[identifier] || specs.first
                 else
                   specs.find { |s| s[:filename] == identifier.to_s } || specs.first
                 end

      selected[:expected_duration].to_f
    end

    # Clean up all test videos (useful for resetting test state)
    def cleanup_test_videos
      FileUtils.rm_rf(TEST_VIDEOS_DIR) if TEST_VIDEOS_DIR.exist?
    end
  end
end

# Auto-include in feature specs
RSpec.configure do |config|
  config.include Features::VideoSampleHelper, type: :feature
  config.include Features::VideoSampleHelper, type: :service
end
