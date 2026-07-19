# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/gathers/_voting.html.erb
#
# These specs intentionally write gather state directly via update_column to
# avoid triggering Gather's heavy state-transition callbacks.
# rubocop:disable Rails/SkipsModelValidations
RSpec.describe 'gathers/_voting', type: :view do
  before do
    view.define_singleton_method(:cuser) { nil }
  end

  def voting_gather
    gather = create(:gather)
    gather.update_column(:status, Gather::STATE_VOTING)
    gather
  end

  it 'renders the captain vote list ordered by votes, with each gatherer vote count' do
    gather = voting_gather
    top_user = create(:user, username: 'TopVotedPlayer')
    create(:gatherer, gather: gather, user: top_user, votes: 5)
    low_user = create(:user, username: 'LowVotedPlayer')
    create(:gatherer, gather: gather, user: low_user, votes: 1)

    render partial: 'gathers/voting', locals: { gather: gather.reload, gatherer: nil }

    expect(rendered).to include('Vote Captains')
    expect(rendered).to include('TopVotedPlayer')
    expect(rendered).to include('LowVotedPlayer')
    expect(rendered).to include('(5)')
    expect(rendered).to include('(1)')
    expect(rendered.index('TopVotedPlayer')).to be < rendered.index('LowVotedPlayer')
  end

  context 'when the viewer has a gatherer in this gather' do
    it 'renders vote links and the voting prompt' do
      gather = voting_gather
      candidate_user = create(:user, username: 'CaptainCandidate')
      create(:gatherer, gather: gather, user: candidate_user)

      voter_user = create(:user)
      voter_gatherer = create(:gatherer, gather: gather, user: voter_user)

      # gather_current_user's default arg (gatherer_from_context) still reads
      # @gatherer directly off the view/controller rather than a local, so it
      # needs to be assigned here even though `gather`/`gatherer` are now locals.
      assign(:gatherer, voter_gatherer)

      render partial: 'gathers/voting', locals: { gather: gather.reload, gatherer: voter_gatherer }

      expect(rendered).to include('vote-link')
      expect(rendered).to include('Click to vote for captain.')
    end
  end

  it 'also renders the server/map vote lists via the nested gathers/votes partial' do
    gather = voting_gather
    server = create(:server, :active, name: 'VotingServerName')
    gather.servers << server

    render partial: 'gathers/voting', locals: { gather: gather.reload, gatherer: nil }

    expect(rendered).to include('Server Votes')
    expect(rendered).to include('VotingServerName')
  end
end
# rubocop:enable Rails/SkipsModelValidations
