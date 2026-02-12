# frozen_string_literal: true

# Service to reconcile directory database records with filesystem state
# Disk is authoritative - scans actual directories and syncs database records
class DirectoryReconciliationService
  def initialize(directory)
    @directory = directory
    @strio = StringIO.new
    @logger = Logger.new(@strio)
  end

  # Returns a StringIO containing the operation log
  def call
    reconcile_with_transaction
    @strio
  end

  private

  def reconcile_with_transaction
    @logger.info("Starting recreate on Directory(#{@directory.id}): #{@directory.name}.")
    @logger.info("DataFiles: #{DataFile.count} Directories: #{Directory.count}")

    ActiveRecord::Base.transaction do
      destroy_dirs = reconcile_recursively
      remove_orphaned_directories(destroy_dirs)
    end

    @logger.info("DataFiles: #{DataFile.count} Directories: #{Directory.count}")
    @logger.info('Finish recreate')
  end

  def reconcile_recursively
    destroy_dirs = {}
    @directory.recreate(destroy_dirs, logger: @logger)
    destroy_dirs
  end

  def remove_orphaned_directories(destroy_dirs)
    @logger.info("Directories to remove: #{destroy_dirs.size}")
    destroy_dirs.each_value do |dir|
      @logger.info("Removed dir: #{dir.name} (ID: #{dir.id}, path: #{dir.path}, parent_id: #{dir.parent_id})")
      # Unlink children and files but keep their records around
      dir.files.update_all(directory_id: nil)
      dir.subdirs.update_all(parent_id: nil)
      dir.preserve_files = true
      dir.destroy!
    end
  end
end
