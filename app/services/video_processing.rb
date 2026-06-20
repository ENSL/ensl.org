# frozen_string_literal: true

# Requires: ffmpeg + ffprobe installed on the host
#
# Usage:
#   VideoProcessingService.random_snapshot!(input_path: "/path/in.mp4", output_path: "/path/out.jpg")
#   VideoProcessingService.transcode_for_web!(
#     input_path: "/path/in.mov",
#     output_path: "/path/out.mp4",
#     max_width: 1920,
#     max_height: 1080
#   )

require 'open3'
require 'fileutils'
require 'securerandom'
require 'bigdecimal'
require 'json'
require 'timeout'

class VideoProcessing
  class Error < StandardError; end
  class CommandFailed < Error; end
  class InvalidInput < Error; end

  FFMPEG  = ENV.fetch('FFMPEG_BIN', 'ffmpeg')
  FFPROBE = ENV.fetch('FFPROBE_BIN', 'ffprobe')

  # Convenience: probe a file, get one-liner, and web-friendly verdict.
  def self.probe_web_compat(path, timeout_s: 10)
    oneliner, meta = video_info_oneliner(path, timeout_s: timeout_s)
    ok, reasons = web_friendly?(meta)
    { oneliner: oneliner, web_friendly: ok, reasons: reasons, metadata: meta }
  end

  # Takes a random snapshot from the video and writes it to output_path.
  # output_path can be .jpg or .png etc.
  #
  # Options:
  # - avoid_edges_seconds: avoid picking a frame too close to start/end
  # - at_seconds: explicit snapshot timestamp (seconds) from start of video
  # - quality: JPEG quality (2 is higher quality in ffmpeg, 2..31)
  # - seed: deterministic selection if desired
  def self.random_snapshot!(
    input_path:,
    output_path:,
    avoid_edges_seconds: 1.0,
    at_seconds: nil,
    quality: 2,
    seed: nil
  )
    input_path  = input_path.to_s
    output_path = output_path.to_s

    validate_file!(input_path)
    ensure_parent_dir!(output_path)

    duration = probe_duration_seconds!(input_path) # Float

    max_seek = [duration - 0.001, 0.0].max

    timestamp = if at_seconds.nil?
                  # Pick a timestamp safely inside the video.
                  t_min = [0.0, avoid_edges_seconds.to_f].max
                  t_max = [duration - avoid_edges_seconds.to_f, 0.0].max

                  # If duration is tiny, just pick 0.
                  if t_max <= t_min + 0.001
                    0.0
                  else
                    rng = seed ? Random.new(seed.to_i) : Random.new
                    t_min + rng.rand * (t_max - t_min)
                  end
                else
                  requested = at_seconds.to_f
                  [[requested, 0.0].max, max_seek].min
                end

    # Use -ss BEFORE -i for faster seek; -frames:v 1 grabs one frame.
    # -q:v controls JPEG quality when output is jpg.
    args = [
      FFMPEG,
      '-y',
      '-hide_banner',
      '-loglevel', 'error',
      '-ss', format('%.3f', timestamp),
      '-i', input_path,
      '-frames:v', '1',
      '-q:v', quality.to_i.to_s,
      output_path
    ]

    run_cmd!(args, 'Snapshot extraction failed', capture: true)
  end

  # Converts a video into a web-friendly MP4 (H.264 + AAC), high quality within reason.
  #
  # Strategy:
  # - Use CRF (quality-based) instead of bitrate
  # - Use a sane preset (slow) for quality/size tradeoff.
  # - Cap resolution to max_width/max_height, preserving aspect ratio.
  # - yuv420p for broad browser/device compatibility.
  # - +faststart for progressive download/streaming.
  #
  # Options:
  # - crf: lower is higher quality; 18–23 typical. 18 ~ visually near-lossless for many sources.
  # - preset: ultrafast..veryslow (slower = smaller file given same quality)
  # - max_width/max_height: caps output size (no upscaling)
  # - audio_bitrate: aac bitrate
  # - fps: optionally force fps (nil keeps source timing)
  def self.transcode_for_web!(
    input_path:,
    output_path:,
    crf: 18,
    preset: 'slow',
    max_width: 1920,
    max_height: 1080,
    audio_bitrate: '160k',
    fps: nil
  )
    input_path  = input_path.to_s
    output_path = output_path.to_s

    validate_file!(input_path)
    ensure_parent_dir!(output_path)

    # Scale filter:
    # - Keeps aspect ratio.
    # - Does NOT upscale (min with iw/ih).
    # - Forces even dimensions (required by many encoders).
    #
    # We'll chain filters.
    vf = [
      "scale=w='min(#{max_width.to_i},iw)':h='min(#{max_height.to_i},ih)':force_original_aspect_ratio=decrease",
      'setsar=1',
      'scale=trunc(iw/2)*2:trunc(ih/2)*2'
    ].join(',')

    args = [
      FFMPEG,
      '-y',
      '-hide_banner',
      '-loglevel', 'error',
      '-i', input_path,

      # Video
      '-vf', vf,
      '-c:v', 'libx264',
      '-preset', preset.to_s,
      '-crf', crf.to_i.to_s,
      '-pix_fmt', 'yuv420p',
      '-movflags', '+faststart',

      # Audio (AAC-LC)
      '-c:a', 'aac',
      '-b:a', audio_bitrate.to_s,
      '-ac', '2'
    ]

    # Optional FPS forcing (generally leave nil unless you need it)
    args += ['-r', fps.to_s] if fps

    args << output_path

    run_cmd!(args, 'Transcoding failed')

    output_path
  end

  def self.probe_duration_seconds!(input_path)
    # Returns duration in seconds as Float. Uses ffprobe JSON output for robustness.
    meta = video_metadata(input_path)
    fmt = meta['format'] || {}
    str = fmt['duration']
    raise CommandFailed, 'Could not read duration via ffprobe' if str.to_s.strip.empty?

    BigDecimal(str.to_s).to_f
  end

  # --- Internals ------------------------------------------------------------

  # Return a one-line human summary and the parsed metadata
  def self.video_info_oneliner(path, timeout_s: 10)
    meta = video_metadata(path, timeout_s: timeout_s)

    fmt = meta['format'] || {}
    streams = meta['streams'] || []

    v = streams.find { |s| s['codec_type'] == 'video' }
    a = streams.find { |s| s['codec_type'] == 'audio' }

    container = (fmt['format_name'] || '').split(',').first || '?'
    duration_s = fmt['duration']&.to_f
    duration_str = if duration_s
                     h = (duration_s / 3600).floor
                     m = ((duration_s % 3600) / 60).floor
                     s = (duration_s % 60)
                     if h.positive?
                       format('%<hours>d:%<minutes>02d:%<seconds>05.2f', hours: h, minutes: m, seconds: s)
                     else
                       format('%<minutes>d:%<seconds>05.2f', minutes: m, seconds: s)
                     end
                   else
                     '?'
                   end

    bitrate_kbps = fmt['bit_rate'] ? (fmt['bit_rate'].to_i / 1000) : nil

    v_codec = v && v['codec_name']
    v_tag   = v && v['codec_tag_string']
    width   = v && v['width']
    height  = v && v['height']
    pix_fmt = v && v['pix_fmt']

    fps = if v && v['avg_frame_rate'].is_a?(String) && v['avg_frame_rate'].include?('/')
            num, den = v['avg_frame_rate'].split('/', 2).map(&:to_f)
            den && den != 0 ? (num / den) : nil
          end

    a_codec = a && a['codec_name']
    a_sr    = a && a['sample_rate']&.to_i
    a_ch    = a && a['channels']&.to_i

    parts = []
    parts << "container=#{container || (fmt['format_name'] || '?')}"
    parts << "duration=#{duration_str}"
    parts << "bitrate=#{bitrate_kbps}kbps" if bitrate_kbps
    if v
      parts << "video=#{v_codec}#{v_tag ? "(#{v_tag})" : ''}"
      parts << "res=#{width}x#{height}" if width && height
      parts << "fps=#{format('%.3g', fps)}" if fps
      parts << "pix_fmt=#{pix_fmt}" if pix_fmt
    else
      parts << 'video=none'
    end
    if a
      parts << "audio=#{a_codec}"
      parts << "sr=#{a_sr}Hz" if a_sr
      parts << "ch=#{a_ch}" if a_ch
    else
      parts << 'audio=none'
    end

    [parts.join(' '), meta]
  end

  # Check whether a file is broadly web-friendly (MP4/H.264/yuv420p + AAC)
  # Returns [boolean, reasons_array]
  def self.web_friendly?(meta)
    fmt = meta['format'] || {}
    streams = meta['streams'] || []

    v = streams.find { |s| s['codec_type'] == 'video' }
    a = streams.find { |s| s['codec_type'] == 'audio' }

    reasons = []

    format_names = (fmt['format_name'] || '').split(',')
    mp4ish = format_names.any? { |n| %w[mp4 mov ismv].include?(n.strip) } || format_names.any? do |n|
      n.strip.include?('mp4')
    end
    reasons << "Container is not MP4/ISO BMFF (reported: #{fmt['format_name'] || '?'})" unless mp4ish

    if v.nil?
      reasons << 'No video stream found'
    else
      v_codec = v['codec_name']
      reasons << "Video codec is not H.264 (reported: #{v_codec || '?'})" unless v_codec == 'h264'

      v_tag = v['codec_tag_string']
      reasons << "Video codec tag is not avc1 (reported: #{v_tag || '?'})" if v_tag && v_tag != 'avc1'

      pix_fmt = v['pix_fmt']
      reasons << "Pixel format not yuv420p (reported: #{pix_fmt || '?'})" if pix_fmt && pix_fmt != 'yuv420p'
    end

    if a.nil?
      reasons << 'No audio stream (OK for silent video, but some UX expects audio)'
    else
      a_codec = a['codec_name']
      reasons << "Audio codec is not AAC (reported: #{a_codec || '?'})" unless a_codec == 'aac'
    end

    [reasons.empty?, reasons]
  end

  # Probe file and return parsed ffprobe JSON metadata (format + streams)
  def self.video_metadata(path, timeout_s: 10)
    raise InvalidInput, "Input not found: #{path}" unless File.exist?(path)

    args = [
      FFPROBE,
      '-v', 'error',
      '-print_format', 'json',
      '-show_format',
      '-show_streams',
      path.to_s
    ]

    json = Timeout.timeout(timeout_s) { run_cmd!(args, 'ffprobe failed', capture: true) }
    JSON.parse(json)
  rescue Timeout::Error => e
    raise CommandFailed, "ffprobe timed out after #{timeout_s}s: #{e.message}"
  rescue JSON::ParserError => e
    raise CommandFailed, "ffprobe returned invalid JSON: #{e.message}"
  end

  # Run a command and return stdout, raising CommandFailed on error.
  # Run a command. On success returns stdout when `capture: true`, otherwise nil.
  # Raises CommandFailed on non-zero exit and includes stderr/stdout in the message.
  def self.run_cmd!(args, user_message = nil, capture: false)
    stdout, stderr, status = Open3.capture3(*args)
    return stdout if status.success? && capture
    return nil if status.success?

    msg = +(user_message || 'Command failed') + ".\nCommand: #{args.join(' ')}\n"
    msg << "STDERR:\n#{stderr.strip}\n" unless stderr.to_s.strip.empty?
    msg << "STDOUT:\n#{stdout.strip}\n" unless stdout.to_s.strip.empty?
    raise CommandFailed, msg
  end

  def self.validate_file!(path)
    raise InvalidInput, "Input not found: #{path}" unless File.file?(path)
    raise InvalidInput, "Input not readable: #{path}" unless File.readable?(path)
  end

  def self.ensure_parent_dir!(output_path)
    FileUtils.mkdir_p(File.dirname(output_path))
  end

  private_class_method :validate_file!, :ensure_parent_dir!, :run_cmd!
end
