require 'rails_helper'

RSpec.describe ServersHelper, type: :helper do
  describe '#server_status_label' do
    it 'returns online for online servers' do
      server = instance_double(Server, online?: true)

      expect(helper.server_status_label(server)).to eq('Status: online')
    end

    it 'returns offline when no offline timestamp is available' do
      server = instance_double(Server, online?: false)
      allow(helper).to receive(:server_offline_since).with(server).and_return(nil)

      expect(helper.server_status_label(server)).to eq('Status: offline')
    end

    it 'formats the offline duration when available' do
      server = instance_double(Server, online?: false)
      since = 2.hours.ago
      allow(helper).to receive(:server_offline_since).with(server).and_return(since)
      allow(helper).to receive(:time_ago_in_words).with(since).and_return('about 2 hours')

      expect(helper.server_status_label(server)).to eq('Status: offline since about 2 hours')
    end
  end

  describe '#server_offline_since' do
    let(:server) { instance_double(Server, status: status, versions: versions) }
    let(:versions) { instance_double('VersionRelation') }
    let(:filtered) { instance_double('FilteredVersions') }
    let(:ordered) { instance_double('OrderedVersions') }
    let(:limited) { instance_double('LimitedVersions') }
    let(:status) { Server::STATUS_OFFLINE }

    it 'returns nil unless the server is offline' do
      allow(server).to receive(:status).and_return(Server::STATUS_ONLINE)

      expect(helper.send(:server_offline_since, server)).to be_nil
    end

    it 'returns the latest online timestamp before going offline' do
      timestamp = 3.hours.ago
      allow(versions).to receive(:where).with('object LIKE ?', "%status: #{Server::STATUS_ONLINE}%").and_return(filtered)
      allow(filtered).to receive(:order).with(created_at: :desc).and_return(ordered)
      allow(ordered).to receive(:limit).with(1).and_return(limited)
      allow(limited).to receive(:pick).with(:created_at).and_return(timestamp)

      expect(helper.send(:server_offline_since, server)).to eq(timestamp)
    end

    it 'returns nil when the lookup raises' do
      allow(versions).to receive(:where).and_raise(StandardError)

      expect(helper.send(:server_offline_since, server)).to be_nil
    end
  end
end
