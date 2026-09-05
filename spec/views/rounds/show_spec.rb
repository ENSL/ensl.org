# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/rounds/show.html.erb's timeline section
# (see RoundsHelper) -- marines render on the left, aliens on the right,
# vertical position reflects elapsed time, and descriptions read as prose
# (nicknames, not steamids) instead of a raw event dump.
RSpec.describe 'rounds/show', type: :view do
  let(:round) do
    Round.create!(
      server_name: 'ENSL Server One',
      map_name: 'ns_eclipse',
      start_time: Time.zone.parse('2026-01-01 12:00:00'),
      end_time: Time.zone.parse('2026-01-01 12:20:00'),
      result: Round::RESULT_MARINE_WIN
    )
  end

  before do
    Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_MARINES, share: 0.5)
    Rounder.create!(round: round, steamid: 'STEAM_0:1:2', team: Rounder::TEAM_ALIENS, share: 0.5)

    assign(:round, round)
  end

  it 'shows a placeholder when no log lines have been imported' do
    assign(:log_lines, [])

    render

    expect(rendered).to include('No event log has been imported for this round yet.')
  end

  it 'positions marine and alien events on opposite sides, using nicknames instead of steamids' do
    marine_kill = LogLine.create!(
      round: round, event_type: 'kill', param1: 'AlienOne', param2: 'machinegun',
      actor_steamid: 'STEAM_0:1:1', target_steamid: 'STEAM_0:1:2',
      raw_text: '"MarineOne<1><STEAM_0:1:1><marine1team>" killed "AlienOne<2><STEAM_0:1:2><alien1team>" ' \
                'with "machinegun"',
      created_at: round.start_time + 30.seconds
    )
    alien_kill = LogLine.create!(
      round: round, event_type: 'kill', param1: 'MarineOne', param2: 'bitegun',
      actor_steamid: 'STEAM_0:1:2', target_steamid: 'STEAM_0:1:1',
      raw_text: '"AlienOne<2><STEAM_0:1:2><alien1team>" killed "MarineOne<1><STEAM_0:1:1><marine1team>" ' \
                'with "bitegun"',
      created_at: round.start_time + 90.seconds
    )

    assign(:log_lines, [marine_kill, alien_kill])

    render

    expect(rendered).to include('round-timeline-row--marine')
    expect(rendered).to include('round-timeline-row--alien')
    expect(rendered).to include('00:30')
    expect(rendered).to include('01:30')
    expect(rendered).to include('MarineOne killed AlienOne with LMG')
    expect(rendered).to include('AlienOne killed MarineOne with Bite')

    marine_top = rendered[/round-timeline-row--marine" style="top: (\d+)px/, 1].to_i
    alien_top = rendered[/round-timeline-row--alien" style="top: (\d+)px/, 1].to_i
    expect(alien_top).to be > marine_top
  end

  it 'folds a gestate + role_change pair into one "started evolving to" entry' do
    raw = '"AlienOne<2><STEAM_0:1:2><alien1team>"'
    gestate = LogLine.create!(round: round, event_type: 'role_change', param1: 'gestate',
                              actor_steamid: 'STEAM_0:1:2', raw_text: "#{raw} changed role to \"gestate\"",
                              created_at: round.start_time + 10.seconds)
    fade = LogLine.create!(round: round, event_type: 'role_change', param1: 'fade', actor_steamid: 'STEAM_0:1:2',
                           raw_text: "#{raw} changed role to \"fade\"", created_at: round.start_time + 20.seconds)

    assign(:log_lines, [gestate, fade])

    render

    expect(rendered).to include('AlienOne started evolving to Fade')
    expect(rendered).not_to include('gestate')
  end

  it 'groups nearby commander item drops into one combined entry' do
    medpack1 = LogLine.create!(round: round, event_type: 'structure_built', param1: 'item_health',
                               actor_steamid: 'STEAM_0:1:1', raw_text: 'drop',
                               created_at: round.start_time + 5.seconds)
    medpack2 = LogLine.create!(round: round, event_type: 'structure_built', param1: 'item_health',
                               actor_steamid: 'STEAM_0:1:1', raw_text: 'drop',
                               created_at: round.start_time + 7.seconds)
    ammo = LogLine.create!(round: round, event_type: 'structure_built', param1: 'item_genericammo',
                           actor_steamid: 'STEAM_0:1:1', raw_text: 'drop', created_at: round.start_time + 9.seconds)

    assign(:log_lines, [medpack1, medpack2, ammo])

    render

    expect(rendered).to include('dropped 2 Medpacks and 1 Ammo Pack')
  end

  it 'escapes raw text for events with no recognized event type' do
    LogLine.create!(
      round: round, event_type: nil, raw_text: '<script>alert(1)</script>',
      created_at: round.start_time + 5.seconds
    )

    assign(:log_lines, LogLine.where(round: round).to_a)

    render

    expect(rendered).not_to include('<script>alert(1)</script>')
    expect(rendered).to include('&lt;script&gt;')
  end
end
