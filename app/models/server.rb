# == Schema Information
#
# Table name: servers
#
#  id              :integer          not null, primary key
#  name            :string(255)
#  description     :string(255)
#  dns             :string(255)
#  ip              :string(255)
#  port            :string(255)
#  rcon            :string(255)
#  password        :string(255)
#  irc             :string(255)
#  user_id         :integer
#  official        :boolean
#  created_at      :datetime
#  updated_at      :datetime
#  map             :string(255)
#  players         :integer
#  max_players     :integer
#  ping            :string(255)
#  version         :integer
#  domain          :integer          default(0), not null
#  reservation     :string(255)
#  recording       :string(255)
#  idle            :datetime
#  default_id      :integer
#  active          :boolean          default(TRUE), not null
#  recordable_type :string(255)
#  recordable_id   :integer
#  category_id     :integer
#

require "rcon"
require "yaml"

class Server < ActiveRecord::Base
  include Extra

  DOMAIN_HLDS = 0
  DOMAIN_HLTV = 1
  DOMAIN_NS2 = 2
  HLTV_IDLE = 1200
  DEMOS = "/var/www/virtual/ensl.org/hlds_l/ns/demos"
  QSTAT = "/usr/bin/quakestat"
  TMPFILE = "tmp/server.txt"

  attr_accessor :rcon_handle, :pwd
  attr_protected :id, :user_id, :updated_at, :created_at, :map, :players, :maxplayers, :ping, :version

  validates_length_of [:name, :dns,], :in => 1..30
  validates_length_of [:rcon, :password, :irc], :maximum => 30, :allow_blank => true
  validates_length_of :description, :maximum => 255, :allow_blank => true
  validates_format_of :ip, :with => /\A[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\z/
    validates_format_of :port, :with => /\A[0-9]{1,5}\z/
    validates_format_of :reservation, :with => /\A[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}\z/, :allow_nil => true
  validates_format_of :pwd, :with => /\A[A-Za-z0-9_\-]*\z/, :allow_nil => true

  scope :ordered, :order => "name"
  scope :hlds, :conditions => ["domain = ?", DOMAIN_HLDS]
  scope :ns2, :conditions => ["domain = ?", DOMAIN_NS2]
  scope :hltvs, :conditions => ["domain = ?", DOMAIN_HLTV]
  scope :active, :conditions => "active = 1"
  scope :with_players, :conditions => "players > 0"
  scope :reserved, :conditions => "reservation IS NOT NULL"
  scope :unreserved_now, :conditions => "reservation IS NULL"
  scope :unreserved_hltv_around,
    lambda { |time| {
    :select => "servers.*",
    :joins => "LEFT JOIN matches ON servers.id = matches.hltv_id
  AND match_time > '#{(time.ago(Match::MATCH_LENGTH).utc).strftime("%Y-%m-%d %H:%M:%S")}'
  AND match_time < '#{(time.ago(-Match::MATCH_LENGTH).utc).strftime("%Y-%m-%d %H:%M:%S")}'",
    :conditions => "matches.hltv_id IS NULL"} }
  scope :of_addr,
    lambda { |addr| {
    :conditions => {
      :ip => addr.match(/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/)[0],
      :port => addr.match(/:([0-9]{1,5})/)[1] } } }
      scope :of_category,
        lambda { |category| {
        :conditions => {:category_id => category.id} }}

      has_many :logs
      has_many :matches
      has_many :challenges
      belongs_to :user
      belongs_to :recordable, :polymorphic => true

      before_create :set_category

      acts_as_versioned
      non_versioned_columns << 'name'
      non_versioned_columns << 'description'
      non_versioned_columns << 'dns'
      non_versioned_columns << 'ip'
      non_versioned_columns << 'port'
      non_versioned_columns << 'rcon'
      non_versioned_columns << 'password'
      non_versioned_columns << 'irc'
      non_versioned_columns << 'user_id'
      non_versioned_columns << 'official'
      non_versioned_columns << 'domain'
      non_versioned_columns << 'reservation'
      non_versioned_columns << 'recording'
      non_versioned_columns << 'idle'
      non_versioned_columns << 'default_id'
      non_versioned_columns << 'active'
      non_versioned_columns << 'recordable_type'
      non_versioned_columns << 'recordable_id'

      def domains
        {DOMAIN_HLTV => "HLTV", DOMAIN_HLDS => "NS Server", DOMAIN_NS2 => "NS2 Server"}
      end

      def to_s
        name
      end

      def addr
        ip + ":" + port.to_s
      end

      def players_s
        if players.nil? or max_players.nil?
          "N/A"
        else
          players.to_s + " / " + max_players.to_s
        end
      end

      def recording_s
        return nil if self.domain != DOMAIN_HLTV
        # recording.to_i > 0 ? Match.find(recording).to_s : recording
        recording
      end

      def reservation_s
        return nil if domain != DOMAIN_HLTV
        reservation
      end

      def graphfile
        File.join("public", "images", "servers", id.to_s + ".png")
      end

      def set_category
        self.category_id = (domain == DOMAIN_NS2 ? 45 : 44 )
      end

      def after_validation_on_update
        if reservation_changed?
          rcon_connect
          if reservation == nil
            rcon_exec "stop"
            self.recording = nil
            self.recordable = nil
            self.idle = nil
            save_demos if self.recording
            hltv_stop
          else
            if changes['reservation'][0].nil?
              hltv_start
              rcon_exec "stop"
              self.recording = recordable.demo_name if recordable and recordable_type == "Match" or recordable_type == "Gather"
              rcon_exec "record demos/" + self.recording if self.recording
            end
            rcon_exec "serverpassword " + pwd
            rcon_exec "connect " + reservation
            self.idle = DateTime.now
          end
          rcon_disconnect
        end
      end

      def execute command
        rcon_connect
        response = rcon_exec command
        rcon_disconnect
        response
      end

      def rcon_connect
        self.rcon_handle = RCon::Query::Original.new(ip, port, rcon)
      end

      def rcon_exec command
        response = rcon_handle.command(command)

        Log.transaction do
          Log.add(self, Log::DOMAIN_RCON_COMMAND, command)
          if response.to_s.length > 0
            Log.add(self, Log::DOMAIN_RCON_RESPONSE, response)
          end
        end

        response
      end

      def rcon_disconnect
        rcon_handle.disconnect
      end

      def hltv_start
        if nr = hltv_nr
          `screen -d -m -S "Hltv-#{nr[1]}" -c $HOME/.screenrc-hltv $HOME/hlds_l/hltv -ip 78.46.36.107 -port 28#{nr[1]}00 +exec ns/hltv#{nr[1]}.cfg`
            sleep 1
        end
      end

      def hltv_nr
        self.name.match(/Tv \#([0-9])/)
      end

      def hltv_stop
        if nr = hltv_nr
          sleep 5
          rcon_exec "exit"
          #`screen -S "Hltv-#{nr[1]}" -X 'quit'`
        end
      end

      def save_demos
        dir = case recordable_type
              when "Match" then
                recordable.contest.demos
              when "Gather" then
                Directory.find(Directory::DEMOS_GATHERS)
              end

        dir ||= Directory.find(Directory::DEMOS_DEFAULT)
        zip_path = File.join(dir.path, recording + ".zip")

        Zip::ZipOutputStream::open(zip_path) do |zos|
          if recordable_type == "Match"
            zos.put_next_entry "readme.txt"
            zos.write "Team1: " + recordable.contester1.to_s + "\r\n"
            zos.write "Team2: " + recordable.contester2.to_s + "\r\n"
            zos.write "Date: " + recordable.match_time.to_s + "\r\n"
            zos.write "Contest: " + recordable.contest.to_s + "\r\n"
            zos.write "Server: " + recordable.server.addr + "\r\n" if recordable.server
            zos.write "HLTV: " + addr + "\r\n"
            zos.write YAML::dump(recordable.attributes).to_s
          end
          Dir.glob("#{DEMOS}/*").each do |file|
            if File.file?(file) and file.match(/#{recording}.*\.dem/)
              zos.put_next_entry File.basename(file)
              zos.write(IO.read(file))
            end
          end
        end

        DataFile.transaction do
          unless dbfile = DataFile.find_by_path(zip_path)
            dbfile = DataFile.new
            dbfile.path = zip_path
            dbfile.directory = dir
            dbfile.save!
            DataFile.update_all({:name => File.basename(zip_path)}, {:id => dbfile.id})
          end
          if recordable_type == "Match"
            recordable.demo = dbfile
            recordable.save
          end
        end
      end

      def make_stats
        graph = Gruff::Line.new
        graph.title = name
        pings = []
        players = []
        labels = {}
        n = 0

        for version in versions.all(:order => "updated_at DESC", :limit => 30).reverse
          pings << version.ping.to_i
          players << version.players.to_i
          labels[n] = version.updated_at.strftime("%H:%M") if n % 3 == 0
          n = n + 1
        end

        graph.theme_37signals
        graph.data("Ping", pings, '#057fc0')
        graph.data("Players", players, '#ff0000')
        graph.labels = labels
        graph.write(graphfile)
      end

      def default_record
        #		if self.default
        #			rcon_exec "record demos/auto-" + Verification.uncrap(default.name)
        #			rcon_exec "serverpassword " + default.password
        #			rcon_exec "connect " + default.addr
        #		end
end

def is_free time
  challenges.around(time).pending.count == 0 and matches.around(time).count == 0
end

def can_create? cuser
  cuser
end

def can_update? cuser
  cuser and cuser.admin? or user == cuser
end

def can_destroy? cuser
  cuser and cuser.admin?
end

def self.refresh
  servers = ""
  Server.hlds.active.all.each do |server|
    servers << " -a2s " + server.ip + ":" + server.port.to_s
  end

  file = File.join(Rails.root, TMPFILE)
  system "#{QSTAT} -xml #{servers} | grep -v '<name>' > #{file}"

  doc = REXML::Document.new(File.new(file).read)
  doc.elements.each('qstat/server') do |server|
    hostname = server.elements['hostname'].text.split(':', 2)
    if s = Server.active.first(:conditions => {:ip => hostname[0], :port => hostname[1]})
      if server.elements.include? 'map'
        s.map = server.elements['map'].text
        s.players = server.elements['numplayers'].text.to_i
        s.max_players = server.elements['maxplayers'].text.to_i
        s.ping = server.elements['ping'].text
        s.map = server.elements['map'].text
        s.save
        s.make_stats
      end
    end
  end

  servers = ""
  Server.hltvs.reserved.each do |server|
    servers << " -a2s #{server.reservation}"
  end

  doc = REXML::Document.new(`#{QSTAT} -xml #{servers} | grep -v '<name>'`)
  doc.elements.each('qstat/server') do |server|
    hostname = server.elements['hostname'].text.split(':', 2)
    if s = Server.hltvs.reserved.first(:conditions => {:ip => hostname[0], :port => hostname[1]})
      if server.elements['numplayers'].text.to_i > 0
        s.update_attribute :idle, DateTime.now
      elsif (s.idle + HLTV_IDLE).past?
        s.reservation = nil
        s.save
      end
    end
  end
end

def self.move addr, newaddr, newpwd
  self.hltvs.all(:conditions => {:reservation => addr}).each do |hltv|
    hltv.reservation = newaddr
    hltv.pwd = newpwd
    hltv.save!
  end
end

def self.stop addr
  self.hltvs.all(:conditions => {:reservation => addr}).each do |hltv|
    hltv.reservation = nil
    hltv.save!
  end
end
end
