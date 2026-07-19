# frozen_string_literal: true

# Service to reconcile directory database records with filesystem state
# Disk is authoritative - scans actual directories and syncs database records
require 'English'
class DirectoryReconciliationService
  PROGRESS_LOG_EVERY = 500
  LOCKFILE_PATH = Rails.root.join('tmp/directory_reconciliation.lock')

  class TeeIO
    def initialize(*targets)
      @targets = targets.compact
    end

    def write(message)
      @targets.each { |target| target.write(message) }
    end

    def close
      @targets.each { |target| target.close unless target.equal?($stdout) }
    end
  end

  def initialize(directory)
    @directory = directory
    @strio = StringIO.new
    @logger = Logger.new(log_output)
    @stats = default_stats
  end

  # Returns a StringIO containing the operation log
  def call
    with_reconciliation_lock { reconcile_with_transaction }
    @strio
  end

  private

  def log_output
    return @strio unless console_session?

    TeeIO.new(@strio, $stdout)
  end

  def console_session?
    defined?(Rails::Console)
  end

  def reconcile_with_transaction
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    @logger.info("Starting recreate on Directory(#{@directory.id}): #{@directory.name}.")
    @logger.info("DataFiles: #{DataFile.count} Directories: #{Directory.count}")
    @logger.info("Progress logging interval: every #{PROGRESS_LOG_EVERY} scanned entries")

    ActiveRecord::Base.transaction do
      destroy_dirs = reconcile_recursively
      remove_orphaned_directories(destroy_dirs)
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    @logger.info("DataFiles: #{DataFile.count} Directories: #{Directory.count}")
    @logger.info(summary_line)
    @logger.info(format('Elapsed: %.2fs', elapsed))
    @logger.info('Finish recreate')
  end

  def with_reconciliation_lock
    FileUtils.mkdir_p(File.dirname(LOCKFILE_PATH))

    lock_file = File.open(LOCKFILE_PATH, File::RDWR | File::CREAT, 0o644)

    unless lock_file.flock(File::LOCK_EX | File::LOCK_NB)
      @logger.info('Skipping reconciliation: another reconciliation is already running')
      lock_file.close
      return
    end

    begin
      yield
    ensure
      lock_file.flock(File::LOCK_UN)
      lock_file.close
    end
  rescue SystemCallError => e
    @logger.error("Failed to acquire reconciliation lock: #{e.message}")
  end

  def reconcile_recursively
    destroy_dirs = {}
    @directory.recreate(
      destroy_dirs,
      logger: @logger,
      stats: @stats,
      progress_every: PROGRESS_LOG_EVERY,
      progress_callback: method(:log_progress)
    )
    destroy_dirs
  end

  def remove_orphaned_directories(destroy_dirs)
    candidates = destroy_dirs.values
    removed_count = 0

    @logger.info("Directories to remove: #{candidates.size}")
    candidates.each do |dir|
      @logger.info("Removed dir: #{dir.name} (ID: #{dir.id}, path: #{dir.path}, parent_id: #{dir.parent_id})")
      # Unlink children and files but keep their records around
      dir.files.find_each do |file|
        file.update!(directory_id: nil)
      end
      dir.subdirs.find_each do |subdir|
        subdir.update!(parent_id: nil)
      end
      dir.preserve_files = true
      dir.destroy!
      removed_count += 1
      @stats[:directories_removed] += 1
    end

    @logger.info("Directories removed: #{removed_count}")
  end

  def log_progress(stats)
    @logger.info(
      "Progress scanned=#{stats[:entries_scanned]} dirs=#{stats[:directories_scanned]} " \
      "files=#{stats[:files_scanned]} " \
      "db_dirs(new=#{stats[:directories_created]}, moved=#{stats[:directories_relinked]}, " \
      "fixed=#{stats[:directories_fixed]}, renamed=#{stats[:directories_renamed]}) " \
      "db_files(new=#{stats[:files_created]}, " \
      "relinked=#{stats[:files_relinked]})"
    )
  end

  def summary_line
    'Reconciliation summary: ' \
      "scanned(entries=#{@stats[:entries_scanned]}, dirs=#{@stats[:directories_scanned]}, " \
      "files=#{@stats[:files_scanned]}) " \
      "db(dirs:new=#{@stats[:directories_created]}, moved=#{@stats[:directories_relinked]}, " \
      "fixed=#{@stats[:directories_fixed]}, renamed=#{@stats[:directories_renamed]}, " \
      "removed=#{@stats[:directories_removed]}; " \
      "files:new=#{@stats[:files_created]}, relinked=#{@stats[:files_relinked]})"
  end

  def default_stats
    {
      entries_scanned: 0,
      directories_scanned: 0,
      files_scanned: 0,
      directories_created: 0,
      directories_relinked: 0,
      directories_fixed: 0,
      directories_renamed: 0,
      directories_removed: 0,
      files_created: 0,
      files_relinked: 0
    }
  end
end
