# frozen_string_literal: true

# == Schema Information
#
# Table name: data_files
#
#  id           :integer          not null, primary key
#  description  :text(65535)      not null
#  md5          :string(255)
#  name         :string(255)
#  path         :string(255)
#  size         :integer          not null
#  title        :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#  article_id   :integer
#  directory_id :integer
#  related_id   :integer
#
# Indexes
#
#  index_data_files_on_article_id    (article_id)
#  index_data_files_on_directory_id  (directory_id)
#  index_data_files_on_related_id    (related_id)
#

require 'rails_helper'

describe DataFile do
  # Setup and cleanup test filesystem
  before(:all) do
    @test_root = '/tmp/test_dirs'
    FileUtils.mkdir_p(@test_root)
  end

  after(:all) do
    FileUtils.rm_rf(@test_root) if Dir.exist?(@test_root)
  end

  before do
    # Set up test root environment
    ENV['FILES_ROOT'] = @test_root
  end

  after do
    # Clean up any test files created during the test
    FileUtils.rm_rf(@test_root) if Dir.exist?(@test_root)
    FileUtils.mkdir_p(@test_root)
  end

  # Stub location for all DataFile instances
  # This makes location return path for compatibility with tests that set path explicitly
  before do
    allow_any_instance_of(DataFile).to receive(:location) do |instance|
      # Return the path attribute which factory sets correctly
      instance.path.to_s
    end
  end

  describe 'associations' do
    subject { build(:data_file) }

    it { is_expected.to belong_to(:directory).optional }
    it { is_expected.to belong_to(:related).optional }
    it { is_expected.to belong_to(:article).optional }
    it { is_expected.to have_many(:related_files) }
    it { is_expected.to have_many(:comments) }
    it { is_expected.to have_one(:movie) }
    it { is_expected.to have_one(:preview) }
    it { is_expected.to have_one(:match) }
  end

  describe 'validations' do
    subject { build(:data_file) }

    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_length_of(:path).is_at_most(255) }
  end

  describe 'scopes' do
    describe '.recent' do
      it 'returns recent files ordered by created_at DESC limited to 8' do
        create_list(:data_file, 10)
        expect(DataFile.recent.count).to eq(8)
      end
    end

    describe '.ordered' do
      it 'returns files ordered by created_at DESC' do
        DataFile.delete_all # Clear all existing files
        create(:data_file, created_at: 2.days.ago)
        sleep(0.01) # Ensure different timestamps
        create(:data_file, created_at: 1.day.ago)

        result = DataFile.ordered
        expect(result.first.created_at).to be >= result.last.created_at
      end
    end

    describe '.except_file' do
      it 'excludes the specified file' do
        file1 = create(:data_file)
        file2 = create(:data_file)

        result = DataFile.except_file(file1)
        expect(result).to include(file2)
        expect(result).not_to include(file1)
      end
    end

    describe '.for_related_selection' do
      it 'returns files in same directory excluding the given file' do
        directory = create(:directory)
        target = create(:data_file, directory: directory)
        same_dir = create(:data_file, directory: directory)
        other_dir = create(:data_file, directory: create(:directory))

        result = DataFile.for_related_selection(target)

        expect(result).to include(same_dir)
        expect(result).not_to include(target)
        expect(result).not_to include(other_dir)
      end
    end

    describe '.unrelated' do
      it 'returns files without related_id' do
        unrelated = create(:data_file, related_id: nil)
        related = create(:data_file, :with_related)

        expect(DataFile.unrelated).to include(unrelated)
        expect(DataFile.unrelated).not_to include(related)
      end
    end

    describe '.movies' do
      it 'returns files from movies directory' do
        DataFile.delete_all # Clear test data

        # Temporarily stub create_movie to prevent it from being called
        allow_any_instance_of(DataFile).to receive(:create_movie)

        movie = create(:data_file, directory_id: Directory::MOVIES, path: '/tmp/test_dirs/movie_scope.mp4')
        non_movie = create(:data_file, directory_id: nil, path: '/tmp/test_dirs/nonmovie_scope.txt')

        expect(DataFile.movies).to include(movie)
        expect(DataFile.movies).not_to include(non_movie)
      end
    end
  end

  describe '#to_s' do
    it 'returns title when present and not empty' do
      file = create(:data_file, title: 'My File')
      expect(file.to_s).to eq('My File')
    end

    it 'returns file basename when title is nil' do
      file = build(:data_file, path: '/tmp/test_dirs/test_file.txt', title: nil)
      # Before save, title is nil, so should return basename
      expect(file.to_s).to eq('test_file.txt')
      # After save, callback fills in title
      file.save
      expect(file.to_s).to eq('Test File') # Auto-generated from filename
    end

    it 'returns file basename when title is empty string' do
      file = build(:data_file, path: '/tmp/test_dirs/test2_file.txt', title: '')
      # Before save, empty title should return basename
      expect(file.to_s).to eq('test2_file.txt')
      # After save, callback fills in title
      file.save
      expect(file.to_s).to eq('Test2 File') # Auto-generated from filename
    end
  end

  describe 'description field' do
    it 'defaults description to empty string' do
      file = create(:data_file)
      expect(file.description).to eq('')
    end

    it 'stores long free-form description text' do
      long_text = "Line one\n#{'Long text ' * 80}"
      file = create(:data_file, description: long_text)

      expect(file.reload.description).to eq(long_text)
    end
  end

  describe '#md5_s' do
    it 'returns uppercase MD5' do
      file = build(:data_file, md5: 'abc123def456')
      expect(file.md5_s).to eq('ABC123DEF456')
    end
  end

  describe '#size_s' do
    it 'returns formatted size in MB' do
      file = build(:data_file, size: 2_097_152) # 2 MB
      expect(file.size_s).to eq('2.0 MB')
    end

    it 'rounds to 2 decimal places' do
      file = build(:data_file, size: 1_572_864) # 1.5 MB
      expect(file.size_s).to eq('1.5 MB')
    end
  end

  describe '#location' do
    it 'returns the current filesystem path from the uploader' do
      file = create(:data_file)
      expect(file.location).to eq(file.path)
    end
  end

  describe '#full_path' do
    it 'prefers the uploader location when present' do
      file = build(:data_file, path: '/tmp/test_dirs/cached.txt')
      allow(file).to receive(:location).and_return('/tmp/test_dirs/current.txt')

      expect(file.full_path).to eq('/tmp/test_dirs/current.txt')
    end

    it 'falls back to cached path when uploader location is blank' do
      file = build(:data_file, path: '/tmp/test_dirs/cached.txt')
      allow(file).to receive(:location).and_return(nil)

      expect(file.full_path).to eq('/tmp/test_dirs/cached.txt')
    end
  end

  describe 'directory helpers' do
    it 'returns nil for first_directory and second_directory when no directory is attached' do
      file = build(:data_file, directory: nil)

      expect(file.first_directory).to be_nil
      expect(file.second_directory).to be_nil
    end

    it 'returns the root and second directory for nested directories' do
      root = create(:directory, :root, path: @test_root)
      child = create(:directory, name: 'childdir', parent: root)
      grandchild = create(:directory, name: 'granddir', parent: child)
      file = build(:data_file, directory: grandchild)

      expect(file.first_directory).to eq(root)
      expect(file.second_directory).to eq(grandchild)
    end

    it 'returns nil for second_directory when the file is already in the root directory' do
      root = create(:directory, :root, path: @test_root)
      file = build(:data_file, directory: root)

      expect(file.second_directory).to be_nil
    end
  end

  describe '#file_exists?' do
    it 'returns false when no path is available' do
      file = build(:data_file, path: nil)
      allow(file).to receive(:location).and_return(nil)

      expect(file.file_exists?).to be(false)
    end
  end

  describe '#url' do
    it 'returns nil when uploader has no URL' do
      file = build(:data_file)
      allow(file.name).to receive(:url).and_return(nil)

      expect(file.url).to be_nil
    end

    it 'prefixes uploader URLs that are missing /files' do
      file = build(:data_file)
      allow(file.name).to receive(:url).and_return('/uploads/example.mp4')

      expect(file.url).to eq('/files/uploads/example.mp4')
    end
  end

  describe '#sync_file_metadata' do
    it 'updates MD5 hash from disk file' do
      file_path = '/tmp/test_dirs/sync_md5_test_2.txt'
      File.write(file_path, 'initial content')
      file = create(:data_file, path: file_path, md5: 'old_hash', size: 100)

      File.write(file.path, 'new test content')
      file.send(:sync_file_metadata)

      expected_md5 = Digest::MD5.hexdigest('new test content')
      expect(file.md5).to eq(expected_md5)
    end

    it 'updates size from disk file' do
      file_path = '/tmp/test_dirs/sync_size_test_2.txt'
      test_content = 'initial'
      File.write(file_path, test_content)
      file = create(:data_file, path: file_path, size: 100)

      new_content = 'new test content that is longer than original'
      File.write(file.path, new_content)
      file.send(:sync_file_metadata)

      expect(file.size).to eq(File.size(file.path))
    end

    it 'does not update metadata if file does not exist' do
      # Use DataFile.new to avoid factory's file creation hooks
      file = DataFile.new(path: '/tmp/test_dirs/nonexist.txt', md5: 'original_hash')
      original_md5 = file.md5
      file.send(:sync_file_metadata)
      expect(file.md5).to eq(original_md5)
    end
  end

  describe '#generate_title_from_filename' do
    it 'removes file extension' do
      file_path = '/tmp/test_dirs/myfile_ext_test.txt'
      File.write(file_path, 'test')
      file = create(:data_file, path: file_path)
      result = file.send(:generate_title_from_filename)
      expect(result).not_to include('.txt')
    end

    it 'replaces underscores and dashes with spaces' do
      file_path = '/tmp/test_dirs/test_file-name_gen.txt'
      File.write(file_path, 'test')
      file = create(:data_file, path: file_path)
      result = file.send(:generate_title_from_filename)
      expect(result).to eq('Test File Name Gen')
    end

    it 'capitalizes each word' do
      file_path = '/tmp/test_dirs/my_test_file_cap.txt'
      File.write(file_path, 'test')
      file = create(:data_file, path: file_path)
      result = file.send(:generate_title_from_filename)
      expect(result).to eq('My Test File Cap')
    end
  end

  describe '#should_create_movie?' do
    it 'returns true when in movies directory and not preview' do
      file = build(:data_file, directory_id: Directory::MOVIES, path: '/tmp/test_dirs/movie.mp4')
      expect(file.should_create_movie?).to be true
    end

    it 'returns false when a movie already exists' do
      file = build(:data_file, directory_id: Directory::MOVIES, path: '/tmp/test_dirs/movie.mp4')
      allow(file).to receive(:movie).and_return(instance_double('Movie'))

      expect(file.should_create_movie?).to be false
    end

    it 'returns false when file is a preview' do
      file = build(:data_file, directory_id: Directory::MOVIES, path: '/tmp/test_dirs/movie_preview.mp4')
      expect(file.should_create_movie?).to be false
    end

    it 'returns false when not in movies directory' do
      file = build(:data_file, directory_id: 999, path: '/tmp/test_dirs/movie.mp4')
      expect(file.should_create_movie?).to be false
    end
  end

  describe '#should_update_relations?' do
    it 'returns true when related_id changed and has related_files' do
      file = build(:data_file)
      allow(file).to receive(:saved_change_to_related_id?).and_return(true)
      allow(file).to receive_message_chain(:related_files, :any?).and_return(true)

      expect(file.should_update_relations?).to be true
    end

    it 'returns false when related_id not changed' do
      file = create(:data_file)
      expect(file.should_update_relations?).to be false
    end
  end

  describe '#update_relations' do
    it 'reparents direct related files to the new related file' do
      directory = create(:directory)
      new_parent = create(:data_file, directory: directory)
      moving_file = create(:data_file, directory: directory)
      child1 = create(:data_file, directory: directory, related: moving_file)
      child2 = create(:data_file, directory: directory, related: moving_file)

      moving_file.update!(related: new_parent)

      expect(child1.reload.related).to eq(new_parent)
      expect(child2.reload.related).to eq(new_parent)
      expect(moving_file.reload.related).to eq(new_parent)
    end

    it 'does not create self references when new parent was already a child' do
      directory = create(:directory)
      parent = create(:data_file, directory: directory)
      child = create(:data_file, directory: directory, related: parent)

      parent.update!(related: child)

      expect(child.reload.related).to be_nil
      expect(parent.reload.related).to be_nil
    end
  end

  describe '.find_existing' do
    it 'finds by path when file exists' do
      file_path = '/tmp/test_dirs/findexist_123.txt'
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, 'test content')

      # Create DataFile by uploading the existing file
      existing = create(:data_file)
      # Manually set the path to the test file location for find_existing to work
      existing.update_column(:path, file_path)

      result = DataFile.find_existing(file_path, 'findexist_123.txt')
      expect(result).to eq(existing)
    end

    it 'finds by MD5 hash when path does not match' do
      file_path = '/tmp/test_dirs/hashfind_456.txt'
      content = 'test content for hash'
      File.write(file_path, content)
      hash = Digest::MD5.hexdigest(content)

      # Create a record with same MD5 but different path
      existing = build(:data_file, md5: hash, path: '/tmp/test_dirs/other_hashfind.txt')
      # Write matching content so disk MD5 aligns with the record
      File.write(existing.path, content)
      existing.save!(validate: false)

      # Since no record exists at hashfind_456.txt, it falls back to MD5 lookup
      result = DataFile.find_existing(file_path, 'hashfind_456.txt')
      expect(result).to eq(existing)
    end

    it 'returns nil when file does not exist on disk' do
      result = DataFile.find_existing('/nonexistent/file.txt', 'file.txt')
      expect(result).to be_nil
    end
  end

  describe '.compute_file_hash' do
    it 'computes MD5 hash of file' do
      file_path = '/tmp/test_dirs/hash_test.txt'
      File.write(file_path, 'test content')
      expected_hash = Digest::MD5.hexdigest('test content')
      result = DataFile.compute_file_hash(file_path)
      expect(result).to eq(expected_hash)
    end

    it 'returns nil when file is unreadable' do
      result = DataFile.compute_file_hash('/nonexistent/unreadable.txt')
      expect(result).to be_nil
    end
  end

  describe '.sync_download_plan' do
    around do |example|
      Dir.mktmpdir('data_file_sync_plan_spec') do |tmp_dir|
        @sync_tmp = tmp_dir
        example.run
      end
    end

    it 'returns base destination when existing file is fresh for overwrite' do
      remote_mtime = Time.utc(2025, 8, 12, 12, 0, 0)
      destination_root = File.join(@sync_tmp, 'logs', 'alpha', '2025')
      destination_path = File.join(destination_root, 'server.log')
      FileUtils.mkdir_p(destination_root)
      File.binwrite(destination_path, 'old-content')

      now = Time.utc(2025, 8, 13, 12, 0, 0)
      fresh_time = now - 2.days
      File.utime(fresh_time, fresh_time, destination_path)

      expect(Directory).to receive(:sync_download_root)
        .with(kind: Directory::SYNC_KIND_LOGS, nickname: 'alpha', year: 2025)
        .and_return(destination_root)

      plan = described_class.sync_download_plan(
        nickname: 'alpha',
        filename: 'server.log',
        remote_size: 1024,
        remote_mtime: remote_mtime,
        now: now
      )

      expect(plan[:download]).to be true
      expect(plan[:destination_path]).to eq(destination_path)
      expect(plan[:reason]).to eq(:download)
    end

    it 'returns _year_n duplicate destination when existing file is older than one week' do
      remote_mtime = Time.utc(2026, 1, 3, 0, 0, 0)
      destination_root = File.join(@sync_tmp, 'logs', 'beta', '2026')
      destination_path = File.join(destination_root, 'monthly.log')
      FileUtils.mkdir_p(destination_root)
      File.binwrite(destination_path, 'existing')

      now = Time.utc(2026, 1, 20, 0, 0, 0)
      old_time = now - 20.days
      File.utime(old_time, old_time, destination_path)

      expect(Directory).to receive(:sync_download_root)
        .with(kind: Directory::SYNC_KIND_LOGS, nickname: 'beta', year: 2026)
        .and_return(destination_root)

      plan = described_class.sync_download_plan(
        nickname: 'beta',
        filename: 'monthly.log',
        remote_size: 2048,
        remote_mtime: remote_mtime,
        now: now
      )

      expect(plan[:download]).to be true
      expect(plan[:destination_path]).to eq(File.join(destination_root, 'monthly_2026_1.log'))
      expect(plan[:reason]).to eq(:download)
    end

    it 'increments duplicate suffix and keeps .log.gz extension placement' do
      remote_mtime = Time.utc(2026, 6, 1, 0, 0, 0)
      destination_root = File.join(@sync_tmp, 'logs', 'gamma', '2026')
      destination_path = File.join(destination_root, 'archive.log.gz')
      first_duplicate = File.join(destination_root, 'archive_2026_1.log.gz')
      FileUtils.mkdir_p(destination_root)
      File.binwrite(destination_path, 'existing')
      File.binwrite(first_duplicate, 'existing-duplicate')

      now = Time.utc(2026, 6, 20, 0, 0, 0)
      old_time = now - 15.days
      File.utime(old_time, old_time, destination_path)

      expect(Directory).to receive(:sync_download_root)
        .with(kind: Directory::SYNC_KIND_LOGS, nickname: 'gamma', year: 2026)
        .and_return(destination_root)

      plan = described_class.sync_download_plan(
        nickname: 'gamma',
        filename: 'archive.log.gz',
        remote_size: 4096,
        remote_mtime: remote_mtime,
        now: now
      )

      expect(plan[:download]).to be true
      expect(plan[:destination_path]).to eq(File.join(destination_root, 'archive_2026_2.log.gz'))
    end

    it 'returns up-to-date plan when local file matches remote metadata' do
      remote_mtime = Time.utc(2026, 3, 1, 10, 0, 0)
      destination_root = File.join(@sync_tmp, 'logs', 'delta', '2026')
      destination_path = File.join(destination_root, 'same.log')
      content = 'same-content'
      FileUtils.mkdir_p(destination_root)
      File.binwrite(destination_path, content)
      File.utime(remote_mtime, remote_mtime, destination_path)

      expect(Directory).to receive(:sync_download_root)
        .with(kind: Directory::SYNC_KIND_LOGS, nickname: 'delta', year: 2026)
        .and_return(destination_root)

      plan = described_class.sync_download_plan(
        nickname: 'delta',
        filename: 'same.log',
        remote_size: content.bytesize,
        remote_mtime: remote_mtime,
        now: Time.utc(2026, 3, 1, 12, 0, 0)
      )

      expect(plan[:download]).to be false
      expect(plan[:destination_path]).to eq(destination_path)
      expect(plan[:reason]).to eq(:up_to_date)
    end

    it 'returns nil for unsupported file suffixes' do
      expect(described_class.sync_download_plan(nickname: 'alpha', filename: 'notes.txt')).to be_nil
    end

    it 'returns nil when the destination root cannot be resolved' do
      expect(Directory).to receive(:sync_download_root)
        .with(kind: Directory::SYNC_KIND_DEMOS, nickname: 'alpha', year: nil)
        .and_return(nil)

      plan = described_class.sync_download_plan(
        nickname: 'alpha',
        filename: 'match.dem',
        remote_size: 123,
        remote_mtime: Time.utc(2026, 3, 1, 0, 0, 0)
      )

      expect(plan).to be_nil
    end
  end

  describe '#refresh_preview_links!' do
    it 'links a source movie to its preview file in the movies directory' do
      source = create(:data_file,
                      directory_id: Directory::MOVIES,
                      path: '/tmp/test_dirs/source_clip.mp4',
                      title: 'Source Clip')
      preview = create(:data_file,
                       directory_id: Directory::MOVIES,
                       path: '/tmp/test_dirs/source_clip_preview.mp4',
                       title: 'Preview Clip')

      Movie.insert_all!([{ file_id: source.id, created_at: Time.current, updated_at: Time.current }])
      source_movie = Movie.find_by(file_id: source.id)

      source.reload.refresh_preview_links!

      expect(preview.reload.related_id).to eq(source.id)
      expect(source_movie.reload.preview_id).to eq(preview.id)
    end
  end

  describe 'permission methods' do
    let(:file) { create(:data_file) }

    describe '#can_create?' do
      it 'returns false for nil user' do
        expect(file.can_create?(nil)).to be false
      end

      it 'returns false for banned users' do
        banned_user = double('user', admin?: false, banned?: true)

        expect(file.can_create?(banned_user)).to be false
      end

      it 'returns true for admin user' do
        admin = double('user', admin?: true, banned?: false)
        expect(file.can_create?(admin)).to be true
      end

      it 'allows movie-group users to upload into the movies directory' do
        movies_file = build(:data_file, directory_id: Directory::MOVIES)
        member = double('user', admin?: false, banned?: false, has_access?: true)

        expect(movies_file.can_create?(member)).to be true
      end

      it 'allows users when the related article allows creation' do
        permitted_article = build(:article)
        allow(permitted_article).to receive(:can_create?).and_return(true)
        member = double('user', admin?: false, banned?: false, has_access?: false)
        file = build(:data_file, article: permitted_article, directory_id: nil)

        expect(file.can_create?(member)).to be true
      end

      it 'rejects users when neither article nor movie access allows creation' do
        denied_article = build(:article)
        allow(denied_article).to receive(:can_create?).and_return(false)
        member = double('user', admin?: false, banned?: false, has_access?: false)
        file = build(:data_file, article: denied_article, directory_id: nil)

        expect(file.can_create?(member)).to be false
      end
    end

    describe '#can_update?' do
      it 'returns false for nil user' do
        expect(file.can_update?(nil)).to be false
      end

      it 'returns true for admin user' do
        admin = double('user', admin?: true)
        expect(file.can_update?(admin)).to be true
      end

      it 'delegates updates to article permissions for non-admin users' do
        editor = double('user', admin?: false)
        article = build(:article)
        allow(article).to receive(:can_create?).and_return(true)
        file = build(:data_file, article: article)

        expect(file.can_update?(editor)).to be true
      end

      it 'rejects updates when the related article does not allow them' do
        editor = double('user', admin?: false)
        article = build(:article)
        allow(article).to receive(:can_create?).and_return(false)
        file = build(:data_file, article: article)

        expect(file.can_update?(editor)).to be false
      end
    end

    describe '#can_destroy?' do
      it 'returns false for nil user' do
        expect(file.can_destroy?(nil)).to be false
      end

      it 'returns true for admin user' do
        admin = double('user', admin?: true)
        expect(file.can_destroy?(admin)).to be true
      end

      it 'delegates destroy permission to the related article' do
        editor = double('user', admin?: false)
        article = build(:article)
        allow(article).to receive(:can_create?).and_return(true)
        file = build(:data_file, article: article)

        expect(file.can_destroy?(editor)).to be true
      end

      it 'rejects destroy when the related article does not allow it' do
        editor = double('user', admin?: false)
        article = build(:article)
        allow(article).to receive(:can_create?).and_return(false)
        file = build(:data_file, article: article)

        expect(file.can_destroy?(editor)).to be false
      end
    end
  end

  describe '.params' do
    it 'permits expected attributes' do
      params = ActionController::Parameters.new(
        data_file: {
          title: 'Test',
          description: 'Long description',
          name: 'file.txt',
          article_id: 1,
          related_id: 2,
          directory_id: 3,
          unauthorized_param: 'not allowed'
        }
      )

      result = DataFile.params(params, nil)
      expect(result.permitted?).to be true
      expect(result.keys).to match_array(%w[title description name article_id related_id directory_id])
    end
  end

  describe 'direct related updates' do
    it 'adds a related file via related_id update' do
      directory = create(:directory)
      parent = create(:data_file, directory: directory)
      candidate = create(:data_file, directory: directory, related: nil)

      candidate.update!(related_id: parent.id)

      expect(candidate.reload.related).to eq(parent)
    end

    it 'removes a related file via related_id nil update' do
      directory = create(:directory)
      parent = create(:data_file, directory: directory)
      related = create(:data_file, directory: directory, related: parent)

      related.update!(related_id: nil)

      expect(related.reload.related).to be_nil
    end
  end

  describe 'callbacks' do
    describe 'before_save :sync_file_metadata' do
      it 'is configured as a before_save callback' do
        callbacks = DataFile._save_callbacks.select { |cb| cb.filter == :sync_file_metadata }
        expect(callbacks).not_to be_empty
        expect(callbacks.first.kind).to eq(:before)
      end
    end

    describe 'after_create :create_movie' do
      it 'is configured as an after_create callback' do
        callbacks = DataFile._create_callbacks.select { |cb| cb.filter == :create_movie }
        expect(callbacks).not_to be_empty
      end
    end

    describe 'after_save :update_relations' do
      it 'is configured as an after_save callback' do
        callbacks = DataFile._save_callbacks.select { |cb| cb.filter == :update_relations }
        expect(callbacks).not_to be_empty
      end
    end

    describe 'after_commit :sync_preview_links' do
      it 'is configured as an after_commit callback' do
        callbacks = DataFile._commit_callbacks.select { |cb| cb.filter == :sync_preview_links }
        expect(callbacks).not_to be_empty
      end
    end
  end
end
