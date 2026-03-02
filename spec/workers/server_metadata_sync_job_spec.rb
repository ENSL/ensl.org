# frozen_string_literal: true

require 'rails_helper'

describe ServerMetadataSyncJob do
  let(:job) { described_class.new }
  let(:gold_src_class) { class_double('SteamCondenser::Servers::GoldSrcServer').as_stubbed_const }
  let(:source_class) { class_double('SteamCondenser::Servers::SourceServer').as_stubbed_const }

  before do
    gold_src_class
    source_class
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:debug)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    it 'processes only active HLDS/NS2 servers and logs totals' do
      hlds_one = create(:server, :active, domain: Server::DOMAIN_HLDS)
      _hlds_two = create(:server, :active, domain: Server::DOMAIN_HLDS)
      ns2 = create(:server, :active, domain: Server::DOMAIN_NS2)
      create(:server, :inactive, domain: Server::DOMAIN_HLDS)
      create(:server, :active, domain: Server::DOMAIN_HLTV)

      allow(job).to receive(:sync_server) do |server|
        case server.id
        when hlds_one.id then :updated
        when ns2.id then :offline
        else :responded
        end
      end

      expect(Rails.logger).to receive(:info).with(
        include('total=3', 'hlds=2', 'ns2=1', 'responded=2', 'updated=1', 'offline=1')
      )

      job.perform

      expect(job).to have_received(:sync_server).exactly(3).times
    end
  end

  describe '#sync_server' do
    it 'updates online status and changed fields when snapshot differs' do
      server = create(
        :server,
        :active,
        domain: Server::DOMAIN_HLDS,
        status: Server::STATUS_OFFLINE,
        map: 'old_map',
        max_players: 10,
        ping: '10'
      )

      allow(job).to receive(:fetch_server_snapshot).with(server).and_return(
        ping: 27.6,
        info: { map_name: 'new_map', max_players: '12' }
      )

      outcome = job.send(:sync_server, server)

      expect(outcome).to eq(:updated)
      expect(server.reload.status).to eq(Server::STATUS_ONLINE)
      expect(server.map).to eq('new_map')
      expect(server.max_players).to eq(12)
      expect(server.ping).to eq('28')
    end

    it 'returns responded when server replies but nothing changes' do
      server = create(
        :server,
        :active,
        domain: Server::DOMAIN_HLDS,
        status: Server::STATUS_ONLINE,
        map: 'same_map',
        max_players: 12,
        ping: '28'
      )

      allow(job).to receive(:fetch_server_snapshot).with(server).and_return(
        ping: nil,
        info: { map_name: 'same_map', max_players: '12' }
      )

      expect(server).not_to receive(:update!)
      expect(Rails.logger).to receive(:debug).with(include('responded without changes'))

      expect(job.send(:sync_server, server)).to eq(:responded)
    end

    it 'marks server offline and returns offline when snapshot fetch fails' do
      server = create(:server, :active, domain: Server::DOMAIN_HLDS)
      error = StandardError.new('unreachable')

      allow(job).to receive(:fetch_server_snapshot).with(server).and_raise(error)
      expect(job).to receive(:mark_offline).with(server, error)

      expect(job.send(:sync_server, server)).to eq(:offline)
    end
  end

  describe '#fetch_server_snapshot' do
    it 'falls back from GoldSrc to Source for HLDS servers' do
      server = create(:server, :active, domain: Server::DOMAIN_HLDS, ip: '127.0.0.1', port: '27015')
      gold_query = instance_double('GoldQuery')
      source_query = instance_double('SourceQuery')

      allow(gold_src_class).to receive(:new).with('127.0.0.1', 27_015).and_return(gold_query)
      allow(source_class).to receive(:new).with('127.0.0.1', 27_015).and_return(source_query)

      allow(gold_query).to receive(:update_ping).and_raise(StandardError, 'timeout')
      allow(source_query).to receive(:update_ping)
      allow(source_query).to receive(:server_info).and_return(map_name: 'ns_veil')
      allow(source_query).to receive(:ping).and_return(14.7)

      expect(job.send(:fetch_server_snapshot, server)).to eq(
        ping: 14.7,
        info: { map_name: 'ns_veil' }
      )
    end

    it 'normalizes non-hash server_info to an empty hash' do
      server = create(:server, :active, domain: Server::DOMAIN_NS2, ip: '127.0.0.2', port: '27016')
      source_query = instance_double('SourceQuery', ping: 16.4)

      allow(source_class).to receive(:new).with('127.0.0.2', 27_016).and_return(source_query)
      allow(source_query).to receive(:update_ping)
      allow(source_query).to receive(:server_info).and_return('invalid')

      expect(job.send(:fetch_server_snapshot, server)).to eq(ping: 16.4, info: {})
    end

    it 'raises combined class-specific errors when all query classes fail' do
      server = create(:server, :active, domain: Server::DOMAIN_HLDS, ip: '127.0.0.3', port: '27017')
      gold_query = instance_double('GoldQuery')
      source_query = instance_double('SourceQuery')

      allow(gold_src_class).to receive(:new).with('127.0.0.3', 27_017).and_return(gold_query)
      allow(source_class).to receive(:new).with('127.0.0.3', 27_017).and_return(source_query)

      allow(gold_query).to receive(:update_ping).and_raise(StandardError, 'timeout')
      allow(source_query).to receive(:update_ping).and_raise(StandardError, 'refused')

      expect { job.send(:fetch_server_snapshot, server) }
        .to raise_error(StandardError,
                        /GoldSrcServer: StandardError: timeout \| .*SourceServer: StandardError: refused/)
    end
  end

  describe '#query_classes_for' do
    it 'returns GoldSrc then Source classes for HLDS servers' do
      server = instance_double(Server, domain: Server::DOMAIN_HLDS)

      expect(job.send(:query_classes_for, server)).to eq([gold_src_class, source_class])
    end

    it 'returns Source class for NS2 servers' do
      server = instance_double(Server, domain: Server::DOMAIN_NS2)

      expect(job.send(:query_classes_for, server)).to eq([source_class])
    end

    it 'returns Source class for unknown domains' do
      server = instance_double(Server, domain: 999)

      expect(job.send(:query_classes_for, server)).to eq([source_class])
    end
  end

  describe '#mark_offline' do
    it 'sets status offline and clears ping when needed' do
      server = create(:server, :active, status: Server::STATUS_ONLINE, ping: '52')
      error = StandardError.new('timeout')

      expect(server).to receive(:update!).with(hash_including(status: Server::STATUS_OFFLINE, ping: nil))
      expect(Rails.logger).to receive(:debug).with(include("#{server.id}", 'offline: StandardError: timeout'))

      job.send(:mark_offline, server, error)
    end

    it 'does not update when already offline with nil ping' do
      server = create(:server, :active, status: Server::STATUS_OFFLINE, ping: nil)

      expect(server).not_to receive(:update!)

      job.send(:mark_offline, server, StandardError.new('timeout'))
    end

    it 'logs an error when marking offline fails' do
      server = create(:server, :active, status: Server::STATUS_ONLINE, ping: '19')
      allow(server).to receive(:update!).and_raise(StandardError, 'db write failed')

      expect(Rails.logger).to receive(:error).with(
        include("Failed to mark server #{server.id} offline", 'StandardError: db write failed')
      )

      job.send(:mark_offline, server, StandardError.new('timeout'))
    end
  end
end
