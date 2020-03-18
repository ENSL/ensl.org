# == Schema Information
#
# Table name: servers
#
#  id              :integer          not null, primary key
#  active          :boolean          default("1"), not null
#  description     :string(255)
#  dns             :string(255)
#  domain          :integer          default("0"), not null
#  idle            :datetime
#  ip              :string(255)
#  irc             :string(255)
#  map             :string(255)
#  max_players     :integer
#  name            :string(255)
#  official        :boolean
#  password        :string(255)
#  ping            :string(255)
#  players         :integer
#  port            :string(255)
#  recordable_type :string(255)
#  recording       :string(255)
#  reservation     :string(255)
#  version         :integer
#  created_at      :datetime
#  updated_at      :datetime
#  category_id     :integer
#  default_id      :integer
#  recordable_id   :integer
#  user_id         :integer
#
# Indexes
#
#  index_servers_on_default_id          (default_id)
#  index_servers_on_players_and_domain  (players,domain)
#  index_servers_on_user_id             (user_id)
#

require "rails_helper"

describe Server do
  describe "create" do
    it "sets category to 45 if domain is NS2" do
      server = create :server, domain: Server::DOMAIN_NS2

      expect(server.category_id).to eq(45)
    end

    it "sets category to 44 if domain is not NS2" do
      server = create :server, domain: Server::DOMAIN_HLDS

      expect(server.category_id).to eq(44)
    end
  end

  describe "addr" do
    it "returns properly formatted IP and port number" do
      ip = "1.1.1.1"
      port = "8000"
      server = create :server, ip: ip, port: port

      expect(server.addr).to eq("1.1.1.1:8000")
    end
  end

  describe "to_s" do
    it "returns server name" do
      server_name = "Foo"
      server = create :server, name: server_name

      expect(server.to_s).to eq(server_name)
    end
  end

  describe "Permissions" do
    let!(:user) { create :user }
    let!(:admin) { create :user, :admin }
    let!(:server_user) { create :user }
    let!(:server) { create :server, user: server_user }

    describe "can_create?" do
      it "returns true for non-admins" do
        expect(server.can_create? user).to be_truthy
      end
    end

    describe "can_destroy?" do
      it "returns true for admin" do
        expect(server.can_destroy? admin).to eq(true)
      end

      it "returns false for non-admins" do
        expect(server.can_destroy? user).to eq(false)
      end
    end

    describe "can_update?" do
      it "returns true for admin" do
        expect(server.can_update? admin).to eq(true)
      end

      it "returns true if server belongs to user" do
        expect(server.can_update? server_user).to eq(true)
      end

      it "returns false for non-admins" do
        expect(server.can_update? user).to eq(false)
      end
    end
  end
end
