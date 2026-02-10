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
      update_root_path_if_needed
      destroy_dirs = reconcile_recursively
      remove_orphaned_directories(destroy_dirs)
    end

    @logger.info("DataFiles: #{DataFile.count} Directories: #{Directory.count}")
    @logger.info('Finish recreate')
  end

  def update_root_path_if_needed
    return unless @directory.id == Directory::ROOT

    @directory.update_attribute(:path, ENV['FILES_ROOT'])
    @logger.info("Path: #{@directory.path}")
  end

  def reconcile_recursively
    destroy_dirs = {}
    @directory.recreate(destroy_dirs, logger: @logger)
    destroy_dirs
  end

  def remove_orphaned_directories(destroy_dirs)
    destroy_dirs.each_value do |dir|
      @logger.info("Removed dir: #{dir.full_path}")
      dir.preserve_files = true
      dir.destroy!
    end
  end
end
