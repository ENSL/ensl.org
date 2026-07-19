# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/gathers/_running.html.erb
RSpec.describe 'gathers/_running', type: :view do
  before do
    view.define_singleton_method(:cuser) { nil }
  end

  it 'renders the signed-up player list' do
    gather = create(:gather, :running)
    player = create(:user, username: 'RunningGatherPlayer')
    create(:gatherer, gather: gather, user: player)

    render partial: 'gathers/running', locals: { gather: gather, gatherer: nil }

    expect(rendered).to include('Signed Up')
    expect(rendered).to include('RunningGatherPlayer')
  end

  it "marks a gatherer with away status as 'away'" do
    gather = create(:gather, :running)
    player = create(:user, username: 'AwayPlayer')
    create(:gatherer, gather: gather, user: player, status: Gatherer::STATE_AWAY)

    render partial: 'gathers/running', locals: { gather: gather, gatherer: nil }

    expect(rendered).to include('AwayPlayer')
    expect(rendered).to include('class="away"')
  end

  context 'when the current user can remove a gatherer' do
    it 'renders a delete link for that gatherer' do
      gather = create(:gather, :running)
      player = create(:user, username: 'RemovablePlayer')
      removable_gatherer = create(:gatherer, gather: gather, user: player)
      signed_in_user = player
      view.define_singleton_method(:cuser) { signed_in_user }

      render partial: 'gathers/running', locals: { gather: gather, gatherer: nil }

      expect(rendered).to include("delete_gatherer_#{removable_gatherer.id}")
    end
  end
end
