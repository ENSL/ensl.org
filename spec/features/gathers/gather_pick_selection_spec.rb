# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Gather pick selection', type: :feature do
  let!(:gather) { create(:gather) }
  let!(:captain) { create(:user) }
  let!(:captain_gatherer) { create(:gatherer, gather: gather, user: captain, team: nil) }
  let!(:candidate) { create(:gatherer, gather: gather) }

  before do
    # rubocop:disable Rails/SkipsModelValidations -- Arrange the in-progress picking state without transition callbacks.
    gather.update_columns(status: Gather::STATE_PICKING, captain1_id: captain_gatherer.id, turn: 1)
    # rubocop:enable Rails/SkipsModelValidations
  end

  scenario 'keeps a selected player checked after a live gather-frame replacement', :js do
    sign_in_via_session(captain)
    visit gather_path(gather)

    player_field = "player_#{candidate.id}"
    choose player_field
    expect(page).to have_checked_field(player_field)

    execute_script <<~JS
      const frame = document.getElementById("frame_gather_#{gather.id}")
      const replacement = frame.cloneNode(true)
      replacement.querySelector("##{player_field}").checked = false
      frame.replaceWith(replacement)
    JS

    expect(page).to have_checked_field(player_field, wait: 5)
  end

  scenario 'sets the gather frame source when sync detects a version change', :js do
    sign_in_via_session(captain)
    visit gather_path(gather)

    execute_script <<~JS
      const frame = document.getElementById("frame_gather_#{gather.id}")
      Object.defineProperty(frame, "src", {
        configurable: true,
        set: (value) => { window.gatherFrameSource = value }
      })
      window.Stimulus
        .getControllerForElementAndIdentifier(document.getElementById("gather"), "gather-sync")
        .reloadFrameOrPage()
    JS

    expect(evaluate_script('window.gatherFrameSource')).to eq(gather_path(gather))
  end
end
