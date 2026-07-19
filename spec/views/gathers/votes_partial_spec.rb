# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/gathers/_votes.html.erb
#
# These specs intentionally write gather state directly via update_column to
# avoid triggering Gather's heavy state-transition callbacks.
# rubocop:disable Rails/SkipsModelValidations
RSpec.describe 'gathers/_votes', type: :view do
  before do
    view.define_singleton_method(:cuser) { nil }
  end

  it 'renders active servers and maps with their current vote counts' do
    gather = create(:gather)
    server = create(:server, :active, name: 'VoteServerName')
    map = create(:map, name: 'ns_votemap')
    gather.servers << server
    gather.maps << map

    gather_server = gather.gather_servers.find_by(server: server)
    gather_map = gather.gather_maps.find_by(map: map)
    gather_server.update!(votes: 3)
    gather_map.update!(votes: 5)

    render partial: 'gathers/votes', locals: { gather: gather.reload }

    expect(rendered).to include('Server Votes')
    expect(rendered).to include('VoteServerName')
    expect(rendered).to include('3')
    expect(rendered).to include('Map Votes')
    expect(rendered).to include('ns_votemap')
    expect(rendered).to include('5')
  end

  it 'excludes inactive servers from the vote list' do
    gather = create(:gather)
    active_server = create(:server, :active, name: 'ActiveVoteServer')
    inactive_server = create(:server, :inactive, name: 'InactiveVoteServer')
    gather.servers << active_server
    gather.servers << inactive_server

    render partial: 'gathers/votes', locals: { gather: gather.reload }

    expect(rendered).to include('ActiveVoteServer')
    expect(rendered).not_to include('InactiveVoteServer')
  end

  context 'when the viewer is able to vote' do
    it 'renders vote links for servers and maps instead of plain text' do
      gather = create(:gather)
      server = create(:server, :active)
      map = create(:map)
      gather.servers << server
      gather.maps << map

      voter_user = create(:user)
      gatherer = create(:gatherer, gather: gather, user: voter_user)
      gather.update_column(:status, Gather::STATE_VOTING)

      # gather_current_user's default arg (gatherer_from_context) still reads
      # @gatherer directly off the view/controller rather than a local, so it
      # needs to be assigned here even though `gather` itself is now a local.
      assign(:gatherer, gatherer)

      render partial: 'gathers/votes', locals: { gather: gather.reload }

      expect(rendered).to include('vote-link')
      expect(rendered).to include('Click to vote')
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
