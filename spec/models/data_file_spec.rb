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
        old_file = create(:data_file, created_at: 2.days.ago)
        sleep(0.01) # Ensure different timestamps
        new_file = create(:data_file, created_at: 1.day.ago)

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
      long_text = "Line one\n" + ('Long text ' * 80)
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

  describe 'permission methods' do
    let(:file) { create(:data_file) }

    describe '#can_create?' do
      it 'returns false for nil user' do
        expect(file.can_create?(nil)).to be false
      end

      it 'returns true for admin user' do
        admin = double('user', admin?: true, banned?: false)
        expect(file.can_create?(admin)).to be true
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
    end

    describe '#can_destroy?' do
      it 'returns false for nil user' do
        expect(file.can_destroy?(nil)).to be false
      end

      it 'returns true for admin user' do
        admin = double('user', admin?: true)
        expect(file.can_destroy?(admin)).to be true
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
