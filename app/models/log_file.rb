# encoding: US-ASCII
# == Schema Information
#
# Table name: log_files
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  md5        :string(255)
#  size       :integer
#  server_id  :integer
#  updated_at :datetime
#


require 'digest/md5'

class LogFile < ActiveRecord::Base
  NON_ASCII = /[\x80-\xff]/
    LOGS = File.join(Rails.root, "tmp", "logs")

  attr_accessor :path
  belongs_to :server

  has_many :log_lines
  has_many :rounds, :through => :log_lines

  def after_create
    Pathname(path).each_line do |line|
      if m = line.gsub(NON_ASCII, "").match(/\d{2}:\d{2}:\d{2}: (.*)/)
        log = LogLine.new
        log.server = server
        log.domain = LogLine::DOMAIN_LOG
        log.log_file = self
        log.text = m[1].strip
        next if log.text.match(/^Server cvar/)
        next if log.text.match(/^\[ENSL\]/)
        next if log.text.match(/STEAM USERID validated/)
        next if log.text.match(/^\[META\]/)
        l.created_at = DateTime.parse(line.match(/\d{2}\/\d{2}\/\d{4} \- \d{2}:\d{2}:\d{2}:/)[0])
        vars = {}
        log.match_map vars or log.match_start vars
        if vars[:round] and !log.details
          log.match_end vars \
            or log.match_join vars \
            or log.match_kill vars \
            or log.match_say vars \
            or log.match_built vars \
            or log.match_destroyed vars \
            or log.match_research_start vars \
            or log.match_research_cancel vars \
            or log.match_role vars \
        end
        if log.details
          log.round = vars[:round] if vars[:round]
          log.save
        end
      end
    end
    rounds.each do |r|
      unless r.end
        r.destroy
      end
    end
    LogLine.delete_all(["details IS NULL AND log_file_id = ?", self.id])
  end

  def format path
    self.name = File.basename(path)
    self.size = File.size(path)
    self.md5 = Digest::MD5.hexdigest(File.read(path))
    self.updated_at = File.mtime(path)
    self.path = path
  end

  def self.process
    Dir.glob("#{LOGS}/*").each do |entry|
      dir = File.basename(entry).to_i
      if File.directory?(entry) and dir > 0 and Server.find(dir)
        Dir.glob("#{entry}/*.log").each do |file|
          lf = LogFile.new
          lf.format file
          lf.server_id = dir

          unless LogFile.find_by(name: lf.name, size: lf.size, server_id: dir.to_i)
            lf.save
          end
        end
      end
    end
  end
end
