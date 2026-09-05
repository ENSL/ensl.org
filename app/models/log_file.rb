# frozen_string_literal: true

# == Schema Information
#
# Table name: log_files
#
#  id          :integer          not null, primary key
#  sha256      :string(255)      not null
#  filename    :string(255)
#  server_name :string(255)
#  created_at  :datetime
#
# Indexes
#
#  index_log_files_on_sha256 (sha256) UNIQUE
#

# One parsed NS1 server log file, imported from the ensl_analysis Python
# pipeline's `log_files` parquet export (see RoundBatchImportService). The
# actual line-by-line log parsing now happens entirely on the Python side
# (ensl_analysis/log_parser.py); the old in-Rails parser below is kept for
# reference but is not wired up anywhere.
#
# `sha256` (the log file's content hash, already computed by the Python
# parser) is the natural key rows are upserted on -- filenames aren't
# trustworthy as an identity (different/reinstalled servers can produce
# files with the same name), and the Python exporter's own `id` is just a
# per-run counter, not stable across export batches.
class LogFile < ApplicationRecord
  has_many :log_lines, dependent: :destroy
  has_many :rounds, through: :log_lines
end

# --- Old Ruby-side NS1 raw log parser -- superseded by ensl_analysis/log_parser.py ---
#
# require 'digest/md5'
#
# class LogFile < ActiveRecord::Base
#   NON_ASCII = /[\x80-\xff]/n
#   LOGS = File.join(Rails.root, "tmp", "logs")
#   DETAIL_MATCHERS = %i[
#     match_end match_join match_kill match_say match_built match_destroyed
#     match_research_start match_research_cancel match_role
#   ].freeze
#
#   attr_accessor :path
#   belongs_to :server
#
#   has_many :log_lines
#   has_many :rounds, :through => :log_lines
#
#   def after_create
#     Pathname(path).each_line do |line|
#       if m = line.gsub(NON_ASCII, "").match(/\d{2}:\d{2}:\d{2}: (.*)/)
#         log = LogLine.new
#         log.server = server
#         log.domain = LogLine::DOMAIN_LOG
#         log.log_file = self
#         log.text = m[1].strip
#         next if log.text.match(/^Server cvar/)
#         next if log.text.match(/^\[ENSL\]/)
#         next if log.text.match(/STEAM USERID validated/)
#         next if log.text.match(/^\[META\]/)
#         l.created_at = DateTime.parse(line.match(/\d{2}\/\d{2}\/\d{4} \- \d{2}:\d{2}:\d{2}:/)[0])
#         vars = {}
#         log.match_map vars or log.match_start vars
#         if vars[:round] and !log.details
#           match_details(log, vars)
#         end
#         if log.details
#           log.round = vars[:round] if vars[:round]
#           log.save
#         end
#       end
#     end
#     rounds.each do |r|
#       unless r.end
#         r.destroy
#       end
#     end
#     LogLine.delete_all(["details IS NULL AND log_file_id = ?", self.id])
#   end
#
#   def format path
#     self.name = File.basename(path)
#     self.size = File.size(path)
#     self.md5 = Digest::MD5.hexdigest(File.read(path))
#     self.updated_at = File.mtime(path)
#     self.path = path
#   end
#
#   def self.process
#     Dir.glob("#{LOGS}/*").each do |entry|
#       dir = File.basename(entry).to_i
#       if File.directory?(entry) and dir > 0 and Server.find(dir)
#         Dir.glob("#{entry}/*.log").each do |file|
#           lf = LogFile.new
#           lf.format file
#           lf.server_id = dir
#
#           unless LogFile.find_by(name: lf.name, size: lf.size, server_id: dir.to_i)
#             lf.save
#           end
#         end
#       end
#     end
#   end
#
#   private
#
#   def match_details(log, vars)
#     DETAIL_MATCHERS.any? { |matcher| log.public_send(matcher, vars) }
#   end
# end

