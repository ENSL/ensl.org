# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataFile do
  before(:all) do
    @test_root = '/tmp/test_carrierwave_files'
  end

  before do
    FileUtils.rm_rf(@test_root)
    FileUtils.mkdir_p(@test_root)
    ENV['FILES_ROOT'] = @test_root
  end

  after do
    FileUtils.rm_rf(@test_root)
  end

  def upload_tempfile(filename:, content:)
    tmp = Tempfile.new(filename)
    tmp.binmode
    tmp.write(content)
    tmp.flush
    tmp.rewind
    tmp
  end

  it 'stores upload under directory relative_path and caches path to stored file' do
    root = create(:directory, :root)
    dir = create(:directory, name: 'Parent', parent: root)

    tmp = upload_tempfile(filename: 'hello.txt', content: 'hello world')

    file = DataFile.new(directory: dir, description: 'x')
    file.name = tmp
    file.skip_file_validation = false
    file.save!
    file.reload

    expect(file.location).to be_present
    expect(File.exist?(file.location)).to be(true)
    expect(file.path).to eq(file.location)

    expected_prefix = File.join(ENV.fetch('FILES_ROOT'), dir.relative_path)
    expect(file.location).to start_with(expected_prefix)
  ensure
    tmp&.close
    tmp&.unlink
  end

  it 'moves the stored file when directory changes' do
    root = create(:directory, :root)
    from_dir = create(:directory, name: 'From', parent: root)
    to_dir = create(:directory, name: 'To', parent: root)

    tmp = upload_tempfile(filename: 'move_me.txt', content: 'abc')

    file = DataFile.new(directory: from_dir, description: 'x')
    file.name = tmp
    file.skip_file_validation = false
    file.save!
    file.reload

    old_location = file.location
    expect(File.exist?(old_location)).to be(true)

    file.update!(directory: to_dir)
    file.reload

    expect(File.exist?(old_location)).to be(false)
    expect(File.exist?(file.location)).to be(true)
    expect(file.path).to eq(file.location)

    expected_prefix = File.join(ENV.fetch('FILES_ROOT'), to_dir.relative_path)
    expect(file.location).to start_with(expected_prefix)
  ensure
    tmp&.close
    tmp&.unlink
  end
end
