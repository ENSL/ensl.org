# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/gathers/_frame.html.erb
#
# These specs intentionally write gather state directly via update_column to
# avoid triggering Gather's heavy state-transition callbacks.
# rubocop:disable Rails/SkipsModelValidations
RSpec.describe 'gathers/_frame', type: :view do
  before do
    view.define_singleton_method(:cuser) { nil }
    # `render_gather` (GathersHelper) writes response headers to report gather
    # state to the client JS. View specs don't set up a real response object.
    allow(view).to receive(:headers).and_return({})
  end

  it 'renders the turbo frame wrapper with the gather version and delegates to the running partial' do
    gather = create(:gather, :running)
    player = create(:user, username: 'FrameRunningPlayer')
    create(:gatherer, gather: gather, user: player)

    render partial: 'gathers/frame', locals: { gather: gather, gatherer: nil }

    expect(rendered).to include('turbo-frame')
    expect(rendered).to include("gather_#{gather.id}_version")
    expect(rendered).to include("data-version=\"#{gather.version}\"")
    expect(rendered).to include('FrameRunningPlayer')
  end

  it 'delegates to the voting partial for a gather in the voting state' do
    gather = create(:gather)
    gather.update_column(:status, Gather::STATE_VOTING)

    render partial: 'gathers/frame', locals: { gather: gather, gatherer: nil }

    expect(rendered).to include('Vote Captains')
  end

  it 'delegates to the picking partial for a gather in the picking state' do
    gather = create(:gather)
    gather.update_column(:status, Gather::STATE_PICKING)

    render partial: 'gathers/frame', locals: { gather: gather, gatherer: nil }

    expect(rendered).to include('Lobby')
    expect(rendered).to include('Marines')
    expect(rendered).to include('Aliens')
  end

  it 'renders flash messages inside the gather-notification container' do
    gather = create(:gather, :running)
    flash[:notice] = 'Gather was successfully updated.'

    render partial: 'gathers/frame', locals: { gather: gather, gatherer: nil }

    expect(rendered).to include('gather-notification')
    expect(rendered).to include('Gather was successfully updated.')
  end
end
# rubocop:enable Rails/SkipsModelValidations
