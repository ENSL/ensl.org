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

    it 'adds an error when probe_metadata cannot identify a movie file' do
      allow(VideoProcessing).to receive(:probe_web_compat).and_return(nil)

      movie.probe_metadata

      expect(movie.errors[:base]).to include('Not a movie file.')
    end

    it 'swallows video processing probe errors for metadata' do
      allow(VideoProcessing).to receive(:probe_web_compat).and_raise(VideoProcessing::Error, 'boom')

      expect { movie.probe_metadata }.not_to raise_error
    end

    it 'sets length from probe_length' do
      movie.file = data_file
      movie.probe_length
      expect(movie.length).to eq(123)
    end

    it 'swallows video processing probe errors for length' do
      allow(VideoProcessing).to receive(:probe_duration_seconds!).and_raise(VideoProcessing::Error, 'boom')

      expect { movie.probe_length }.not_to raise_error
    end

    it 'make_snapshot calls VideoProcessing.random_snapshot!' do
      movie.file = data_file
      expect(VideoProcessing).to receive(:random_snapshot!).with(input_path: data_file.location,
                                                                 output_path: instance_of(String),
                                                                 at_seconds: nil)
      movie.make_snapshot
    end

    it 'returns false when make_snapshot has no readable source path' do
      allow(movie).to receive(:processable_source_path).and_return(nil)

      expect(movie.make_snapshot).to be(false)
    end

    it 'returns false when snapshot generation fails' do
      allow(VideoProcessing).to receive(:random_snapshot!).and_raise(VideoProcessing::Error, 'boom')

      expect(movie.make_snapshot).to be(false)
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
        DataFile.create!(
          directory_id: directory.id,
          name: 'clip.mp4',
          path: source_path,
          size: File.size(source_path),
          md5: Digest::MD5.file(source_path).hexdigest,
          description: 'clip.mp4',
          created_at: File.mtime(source_path),
          updated_at: Time.current
        )

        source_file = DataFile.find_by(path: source_path)
        Movie.create!(file_id: source_file.id)
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

      it 'keeps existing user when username lookup misses' do
        movie.user = nil
        allow(User).to receive(:find_by).with(username: 'missing').and_return(nil)
        movie.user_name = 'missing'

        movie.assign_user_from_user_name

        expect(movie.user).to be_nil
      end
    end

    context 'preview_path and preview_url' do
      it 'builds preview_path from file location' do
        allow(data_file).to receive(:location).and_return('/var/www/public/uploads/video.mp4')
        movie.file = data_file
        expect(movie.preview_path).to end_with('_preview.mp4')
      end

      it 'returns nil preview_path when file has no location' do
        allow(data_file).to receive(:location).and_return(nil)
        movie.file = data_file

        expect(movie.preview_path).to be_nil
      end

      it 'reloads file when preview_path is called on a new record' do
        fresh_movie = described_class.new
        file_with_reload = instance_double('DataFile', location: '/tmp/new_movie.mp4')
        allow(file_with_reload).to receive(:respond_to?).with(:reload).and_return(true)
        allow(file_with_reload).to receive(:reload)
        allow(file_with_reload).to receive(:location).and_return('/tmp/new_movie.mp4')
        fresh_movie.file = file_with_reload

        fresh_movie.preview_path

        expect(file_with_reload).to have_received(:reload)
      end

      it 'returns preview.url if preview file exists' do
        allow(preview_file).to receive(:url).and_return('/uploads/prev.mp4')
        movie.preview = preview_file
        expect(movie.preview_url).to eq('/uploads/prev.mp4')
      end

      it 'builds preview_url from preview_path when preview file exists on disk' do
        preview_path = Rails.root.join('public/local/movie_preview_url_spec.mp4')
        FileUtils.mkdir_p(File.dirname(preview_path))
        File.binwrite(preview_path, 'preview')

        movie.preview = nil
        allow(movie).to receive(:preview_path).and_return(preview_path.to_s)

        expect(movie.preview_url).to eq('/local/movie_preview_url_spec.mp4')
      ensure
        FileUtils.rm_f(preview_path)
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

    context '#preview_exists?' do
      it 'returns true when preview data file exists' do
        movie.preview = preview_file

        expect(movie.preview_exists?).to be(true)
      end

      it 'returns false when neither preview record nor preview path exists' do
        movie.preview = nil
        allow(movie).to receive(:preview_path).and_return(nil)

        expect(movie.preview_exists?).to be(false)
      end
    end

    context '#original_url' do
      it 'returns nil when original file is not web friendly' do
        movie.file = data_file
        movie.web_friendly = false

        expect(movie.original_url).to be_nil
      end

      it 'returns nil when file is missing on disk' do
        allow(data_file).to receive(:file_exists?).and_return(false)
        movie.file = data_file
        movie.web_friendly = true

        expect(movie.original_url).to be_nil
      end
    end

    context '#processable_source_path' do
      it 'returns nil when file location is blank' do
        allow(movie).to receive(:processable_source_path).and_call_original
        allow(data_file).to receive(:location).and_return(nil)
        movie.file = data_file

        expect(movie.processable_source_path).to be_nil
      end

      it 'returns nil when file is not readable' do
        allow(movie).to receive(:processable_source_path).and_call_original
        allow(data_file).to receive(:location).and_return('/tmp/unreadable.mp4')
        movie.file = data_file
        allow(File).to receive(:file?).with('/tmp/unreadable.mp4').and_return(true)
        allow(File).to receive(:readable?).with('/tmp/unreadable.mp4').and_return(false)

        expect(movie.processable_source_path).to be_nil
      end
    end

    context '#make_stream' do
      it 'spawns vlc and stores the detached process id for valid stream settings' do
        movie.file = data_file
        movie.stream_ip = '10.0.0.15'
        movie.stream_port = '8080'

        expect(Process).to receive(:spawn).with(
          Movie::VLC,
          'http://10.0.0.15:8080',
          '--sout',
          a_string_including('dst=/var/media/video.mp4'),
          'vlc://quit'
        ).and_return(4321)
        expect(Process).to receive(:detach).with(4321)
        expect(movie).to receive(:update_column).with(:status, 4321)

        expect(movie.send(:make_stream)).to include('access=http')
      end

      it 'returns nil when stream settings are incomplete' do
        movie.file = data_file
        movie.stream_ip = 'not-an-ip'
        movie.stream_port = nil

        expect(Process).not_to receive(:spawn)
        expect(movie.send(:make_stream)).to be_nil
      end

      it 'returns nil when spawning vlc fails' do
        movie.file = data_file
        movie.stream_ip = '10.0.0.15'
        movie.stream_port = '8080'
        allow(Process).to receive(:spawn).and_raise(StandardError, 'spawn failed')

        expect(movie.send(:make_stream)).to be_nil
      end
    end

    context 'private helpers and permissions' do
      it 'creates snapshot directory when missing before writing snapshot' do
        movie.file = data_file
        dir = File.dirname(movie.snapshot_path)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(dir).and_return(false)
        allow(File).to receive(:exist?).with(movie.snapshot_path).and_return(false)

        expect(FileUtils).to receive(:mkdir_p).with(dir)
        movie.make_snapshot
      end

      it 'returns nil from fallback preview helper when source is blank' do
        allow(data_file).to receive(:location).and_return(nil)
        movie.file = data_file

        expect(movie.send(:make_preview_fallback_for_test)).to be_nil
      end

      it 'supports filtering by non-numeric author usernames' do
        author = create(:user, username: 'movie_author')
        category = create(:category)
        file = create(:data_file, :movie)
        create(:movie, user: author, category: category, file: file)

        relation = described_class.filter_or_all('date', nil, nil, 'movie_author')

        expect(relation).to be_a(ActiveRecord::Relation)
      end

      it 'rejects updates and destroy for unrelated regular users' do
        owner = create(:user)
        outsider = create(:user)
        record = create(:movie, user: owner)

        expect(record.can_update?(outsider)).to be(false)
        expect(record.can_destroy?(outsider)).to be(false)
      end
    end

    it 'to_s delegates to file.to_s' do
      allow(data_file).to receive(:to_s).and_return('file-string')
      movie.file = data_file
      expect(movie.to_s).to eq('file-string')
    end
  end

  describe 'destroy behavior with shared data files' do
    it 'does not destroy a shared data file when one movie is removed' do
      shared_file = create(:data_file, :movie)
      first_movie = create(:movie, file: shared_file)
      second_movie = create(:movie, file: shared_file)

      expect { first_movie.destroy }.not_to change(DataFile, :count)
      expect(DataFile.exists?(shared_file.id)).to be(true)
      expect(second_movie.reload.file_id).to eq(shared_file.id)
    end
  end
end
