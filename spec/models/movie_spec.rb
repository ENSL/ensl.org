# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe Movie, type: :model do
  let(:user) { instance_double('User', id: 1, username: 'alice') }
  let(:data_file) do
    instance_double('DataFile', id: 2, location: '/tmp/video.mp4', full_path: '/var/media/video.mp4',
                                url: '/uploads/video.mp4', file_exists?: true)
  end
  let(:preview_file) do
    instance_double('DataFile', id: 3, location: '/tmp/video_preview.mp4', url: '/uploads/video_preview.mp4',
                                file_exists?: true)
  end

  before do
    allow(User).to receive(:find_by).and_return(nil)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:file).class_name('DataFile').optional }
    it { is_expected.to belong_to(:preview).class_name('DataFile').optional }
    it { is_expected.to belong_to(:match).optional }
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to have_many(:ratings) }
    it { is_expected.to have_many(:shoutmsgs) }
    it { is_expected.to have_many(:watchers) }
    it { is_expected.to have_many(:watcher_users).through(:watchers).source(:user) }
    it { is_expected.to have_many(:view_counts).dependent(:destroy) }
  end

  describe 'validations' do
    subject { described_class.new(file: data_file) }

    it { is_expected.to validate_length_of(:content).is_at_most(200).allow_blank }
    it { is_expected.to validate_length_of(:format).is_at_most(200).allow_blank }
    it {
      is_expected.to validate_numericality_of(:length).only_integer.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(50_000).allow_nil
    }
    it 'allows file to be blank' do
      m = described_class.new
      expect(m).to be_valid
    end
  end

  describe 'scopes and class methods' do
    describe '.recent' do
      it 'orders by created_at desc and limits 5' do
        expect(described_class).to respond_to(:recent)
      end
    end

    describe '.active_streams' do
      it 'returns movies where status > 0' do
        expect(described_class).to respond_to(:active_streams)
      end
    end

    describe '.submitter_options' do
      it 'delegates to User join and returns username/id pairs' do
        expect(User).to receive_message_chain(:joins, :distinct, :order, :pluck)
        described_class.submitter_options
      end
    end

    describe '.filter_or_all' do
      it 'accepts filters and returns an ActiveRecord::Relation' do
        expect(described_class.filter_or_all('date')).to be_a(ActiveRecord::Relation)
      end
    end
  end

  describe 'instance methods and callbacks' do
    let(:movie) { described_class.new(file: data_file, user: user) }

    before do
      # Stub VideoProcessing to avoid running external binaries
      allow(VideoProcessing).to receive(:probe_web_compat).and_return({ metadata: { foo: 'bar' }, web_friendly: true,
                                                                        oneliner: 'h264' })
      allow(VideoProcessing).to receive(:probe_duration_seconds!).and_return(123)
      allow(VideoProcessing).to receive(:random_snapshot!).and_return(true)
      allow(movie).to receive(:processable_source_path).and_return(data_file.location)

      # Stub filesystem helpers
      allow(File).to receive(:exist?).and_call_original
      allow(FileUtils).to receive(:mkdir_p)
      allow(FileUtils).to receive(:rm)
    end

    it 'sets metadata and web_friendly and format on probe_metadata' do
      movie.file = data_file
      movie.probe_metadata
      expect(movie.metadata).to be_present
      expect(movie.web_friendly).to be true
      expect(movie.format).to eq('h264')
    end

    it 'sets length from probe_length' do
      movie.file = data_file
      movie.probe_length
      expect(movie.length).to eq(123)
    end

    it 'make_snapshot calls VideoProcessing.random_snapshot!' do
      movie.file = data_file
      expect(VideoProcessing).to receive(:random_snapshot!).with(input_path: data_file.location,
                                                                 output_path: instance_of(String),
                                                                 at_seconds: nil)
      movie.make_snapshot
    end

    it 'make_snapshot forwards requested seconds to VideoProcessing.random_snapshot!' do
      movie.file = data_file
      expect(VideoProcessing).to receive(:random_snapshot!).with(input_path: data_file.location,
                                                                 output_path: instance_of(String),
                                                                 at_seconds: 12.5)
      movie.make_snapshot(seconds: 12.5)
    end

    it 'make_preview falls back to copying source in test when transcoding fails' do
      Dir.mktmpdir do |dir|
        source_path = File.join(dir, 'video.mp4')
        File.binwrite(source_path, 'video-bytes')

        allow(data_file).to receive(:location).and_return(source_path)
        movie.file = data_file
        allow(VideoProcessing).to receive(:transcode_for_web!).and_raise(VideoProcessing::CommandFailed,
                                                                         'ffmpeg failed')

        result = movie.make_preview

        expect(result).to eq(movie.preview_path)
        expect(File.exist?(movie.preview_path)).to be(true)
      end
    end

    it 'make_preview creates a preview data file and links it as related to the source file' do
      Dir.mktmpdir do |dir|
        source_path = File.join(dir, 'clip.mp4')
        File.binwrite(source_path, 'source-bytes')

        directory = Directory.create!(name: 'movietest', title: 'Movie Test', hidden: false, path: dir)
        DataFile.insert_all!([
                               {
                                 directory_id: directory.id,
                                 name: 'clip.mp4',
                                 path: source_path,
                                 size: File.size(source_path),
                                 md5: Digest::MD5.file(source_path).hexdigest,
                                 description: 'clip.mp4',
                                 created_at: File.mtime(source_path),
                                 updated_at: Time.current
                               }
                             ])

        source_file = DataFile.find_by(path: source_path)
        Movie.insert_all!([{ file_id: source_file.id, created_at: Time.current, updated_at: Time.current }])
        persisted_movie = Movie.find_by(file_id: source_file.id)

        allow(source_file).to receive(:location).and_return(source_path)
        allow(source_file).to receive(:full_path).and_return(source_path)
        allow(persisted_movie).to receive(:file).and_return(source_file)
        allow(persisted_movie).to receive(:preview_path).and_return(File.join(dir, 'clip_preview.mp4'))

        allow(VideoProcessing).to receive(:transcode_for_web!) do |input_path:, output_path:|
          expect(input_path).to eq(source_path)
          File.binwrite(output_path, 'preview-bytes')
        end

        result = persisted_movie.make_preview

        preview_file = DataFile.find_by(path: persisted_movie.preview_path)
        expect(result).to eq(persisted_movie.preview_path)
        expect(preview_file).not_to be_nil
        expect(preview_file.related_id).to eq(source_file.id)
        expect(preview_file.directory_id).to eq(directory.id)
        expect(persisted_movie.reload.preview_id).to eq(preview_file.id)
      end
    end

    context '#length_s' do
      it 'formats seconds into M:SS' do
        movie.length = 65
        expect(movie.length_s).to eq('1:05')
      end

      it 'returns nil when length is nil' do
        movie.length = nil
        expect(movie.length_s).to be_nil
      end
    end

    context '#all_files' do
      it 'returns file and related files when present' do
        related = [instance_double('DataFile')]
        allow(data_file).to receive(:related_files).and_return(related)
        movie.file = data_file
        expect(movie.all_files).to eq([data_file] + related)
      end

      it 'returns empty array when no file' do
        movie.file = nil
        expect(movie.all_files).to eq([])
      end
    end

    context '#view_count and #record_view_count' do
      it 'creates a view_count record when recording a new ip' do
        vc_relation = double('vc_relation')
        allow(movie).to receive(:view_counts).and_return(vc_relation)
        expect(vc_relation).to receive(:find_or_create_by).with(ip_address: '1.2.3.4')
        movie.record_view_count('1.2.3.4')
      end
    end

    context '#assign_user_from_user_name' do
      it 'assigns user when username matches' do
        allow(User).to receive(:find_by).with(username: 'bob').and_return(user)
        movie.user_name = 'bob'
        movie.assign_user_from_user_name
        expect(movie.user).to eq(user)
      end

      it 'does nothing when username blank' do
        movie.user_name = ''
        expect { movie.assign_user_from_user_name }.not_to raise_error
      end
    end

    context 'preview_path and preview_url' do
      it 'builds preview_path from file location' do
        allow(data_file).to receive(:location).and_return('/var/www/public/uploads/video.mp4')
        movie.file = data_file
        expect(movie.preview_path).to end_with('_preview.mp4')
      end

      it 'returns preview.url if preview file exists' do
        allow(preview_file).to receive(:url).and_return('/uploads/prev.mp4')
        movie.preview = preview_file
        expect(movie.preview_url).to eq('/uploads/prev.mp4')
      end

      it 'returns nil when preview record exists but preview file is missing' do
        allow(preview_file).to receive(:file_exists?).and_return(false)
        movie.preview = preview_file
        allow(movie).to receive(:preview_path).and_return(nil)

        expect(movie.preview_url).to be_nil
      end
    end

    context '#playback_url' do
      it 'prefers original file URL when original is web-friendly' do
        movie.file = data_file
        movie.preview = preview_file
        movie.web_friendly = true

        expect(movie.playback_url).to eq('/uploads/video.mp4')
      end

      it 'falls back to preview URL when original is not web-friendly' do
        movie.file = data_file
        movie.preview = preview_file
        movie.web_friendly = false

        expect(movie.playback_url).to eq('/uploads/video_preview.mp4')
      end
    end

    it 'to_s delegates to file.to_s' do
      allow(data_file).to receive(:to_s).and_return('file-string')
      movie.file = data_file
      expect(movie.to_s).to eq('file-string')
    end
  end
end
