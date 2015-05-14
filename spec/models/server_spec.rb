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

require 'spec_helper'

describe Server do
	describe 'create' do
		it 'sets category to 45 if domain is NS2' do
			server = create :server, domain: Server::DOMAIN_NS2
			expect(server.category_id).to eq(45)
		end
		it 'sets category to 44 if domain is not NS2' do
			server = create :server, domain: Server::DOMAIN_HLDS
			expect(server.category_id).to eq(44)
		end
	end

	describe 'addr' do
		it 'returns properly formatted IP and port number' do
			ip = '1.1.1.1'
			port = '8000'
			server = create :server, ip: ip, port: port
			expect(server.addr).to eq('1.1.1.1:8000')
		end
	end

	describe 'to_s' do
		it 'returns server name' do
			server_name = "Foo"
			server = create :server, name: server_name
			expect(server.to_s).to eq(server_name)
		end
	end

	describe 'Permissions' do
		let!(:user) { create :user }
		let!(:admin) { create :user, :admin }
		let!(:server_user) {create :user }
		let!(:server) { create :server, user: server_user }

		describe 'can_create?' do
			it 'returns true for non-admins' do
				expect(server.can_create? user).to be_true
			end
		end

		describe 'can_destroy?' do
			it 'returns true for admin' do
				expect(server.can_destroy? admin).to be_true
			end
			it 'returns false for non-admins' do
				expect(server.can_destroy? user).to be_false
			end
		end

		describe 'can_update?' do
			it 'returns true for admin' do
				expect(server.can_update? admin).to be_true
			end
			it 'returns true if server belongs to user' do
				expect(server.can_update? server_user).to be_true
			end
			it 'returns false for non-admins' do
				expect(server.can_update? user).to be_false
			end
		end
	end
end
