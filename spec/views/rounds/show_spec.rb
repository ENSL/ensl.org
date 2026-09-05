# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/rounds/show.html.erb's timeline section
# and Players tables (see RoundsHelper) -- marines render on the left, aliens
# on the right, vertical position reflects elapsed time, and descriptions
# read as prose (nicknames, not steamids) instead of a raw event dump.
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

  def player_raw(name, steamid, team)
    "\"#{name}<1><#{steamid}><#{team}>\""
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
      raw_text: "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} killed " \
                "#{player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team')} with \"machinegun\"",
      created_at: round.start_time + 30.seconds
    )
    alien_kill = LogLine.create!(
      round: round, event_type: 'kill', param1: 'MarineOne', param2: 'bitegun',
      actor_steamid: 'STEAM_0:1:2', target_steamid: 'STEAM_0:1:1',
      raw_text: "#{player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team')} killed " \
                "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} with \"bitegun\"",
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

  it 'renders side from Rounder#team as-is, even when it disagrees with raw_text (by design -- ' \
     'see /memories/repo/round-timeline.md; import-side mistakes should stay visible, not be papered over)' do
    # Rounder says STEAM_0:1:1 is on the ALIEN team for this round (a real,
    # confirmed upstream Python/log-parser bug -- see round 1130/542 notes),
    # even though every actual in-round log line has them on marine1team.
    # The timeline must still follow Rounder#team, not the log line, so the
    # mistake is visible in the UI instead of silently hidden here.
    Rounder.where(round: round, steamid: 'STEAM_0:1:1').update!(team: Rounder::TEAM_ALIENS)

    kill = LogLine.create!(
      round: round, event_type: 'kill', param1: 'AlienOne', param2: 'machinegun',
      actor_steamid: 'STEAM_0:1:1', target_steamid: 'STEAM_0:1:2',
      raw_text: "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} killed " \
                "#{player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team')} with \"machinegun\"",
      created_at: round.start_time + 30.seconds
    )

    assign(:log_lines, [kill])

    render

    kill_row = rendered[/(round-timeline-row--\w+)"[^>]*>(?:(?!round-timeline-row).)*MarineOne killed AlienOne/m, 1]
    expect(kill_row).to eq('round-timeline-row--alien')
  end

  it 'suppresses individual join_team spam and shows one roster summary per side instead' do
    join = LogLine.create!(round: round, event_type: 'join_team', actor_steamid: 'STEAM_0:1:1',
                           raw_text: "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} joined team " \
                                     '"marine1team"',
                           created_at: round.start_time + 1.second)

    assign(:log_lines, [join])

    render

    expect(rendered).not_to include('joined')
    expect(rendered).to include('Marines: MarineOne')
    expect(rendered).to include('Aliens: STEAM_0:1:2')
  end

  it 'suppresses routine skulk/marine respawns but keeps a chair step-down distinct' do
    respawn_skulk = LogLine.create!(round: round, event_type: 'role_change', param1: 'skulk',
                                    actor_steamid: 'STEAM_0:1:2',
                                    raw_text: player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team'),
                                    created_at: round.start_time + 5.seconds)
    became_commander = LogLine.create!(round: round, event_type: 'role_change', param1: 'commander',
                                       actor_steamid: 'STEAM_0:1:1',
                                       raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                                       created_at: round.start_time + 10.seconds)
    left_chair = LogLine.create!(round: round, event_type: 'role_change', param1: 'soldier',
                                 actor_steamid: 'STEAM_0:1:1',
                                 raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                                 created_at: round.start_time + 20.seconds)
    respawn_soldier = LogLine.create!(round: round, event_type: 'role_change', param1: 'soldier',
                                      actor_steamid: 'STEAM_0:1:1',
                                      raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                                      created_at: round.start_time + 30.seconds)

    assign(:log_lines, [respawn_skulk, became_commander, left_chair, respawn_soldier])

    render

    expect(rendered).not_to include('became a Skulk')
    expect(rendered).not_to include('became a Marine')
    expect(rendered).to include('MarineOne took command')
    expect(rendered).to include('MarineOne left the chair')
  end

  it 'distinguishes evolving to a new lifeform from upgrading the same one' do
    gestate1 = LogLine.create!(round: round, event_type: 'role_change', param1: 'gestate',
                               actor_steamid: 'STEAM_0:1:2',
                               raw_text: player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team'),
                               created_at: round.start_time + 10.seconds)
    fade = LogLine.create!(round: round, event_type: 'role_change', param1: 'fade', actor_steamid: 'STEAM_0:1:2',
                           raw_text: player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team'),
                           created_at: round.start_time + 20.seconds)
    gestate2 = LogLine.create!(round: round, event_type: 'role_change', param1: 'gestate',
                               actor_steamid: 'STEAM_0:1:2',
                               raw_text: player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team'),
                               created_at: round.start_time + 60.seconds)
    fade_again = LogLine.create!(round: round, event_type: 'role_change', param1: 'fade',
                                 actor_steamid: 'STEAM_0:1:2',
                                 raw_text: player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team'),
                                 created_at: round.start_time + 70.seconds)

    assign(:log_lines, [gestate1, fade, gestate2, fade_again])

    render

    expect(rendered).to include('AlienOne started evolving to Fade')
    expect(rendered).to include('AlienOne started upgrading')
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

  it 'shows a running total when resource towers/chambers are built and destroyed' do
    rt1 = LogLine.create!(round: round, event_type: 'structure_built', param1: 'resourcetower',
                          actor_steamid: 'STEAM_0:1:1', raw_text: 'built',
                          created_at: round.start_time + 5.seconds)
    rt2 = LogLine.create!(round: round, event_type: 'structure_built', param1: 'resourcetower',
                          actor_steamid: 'STEAM_0:1:1', raw_text: 'built',
                          created_at: round.start_time + 10.seconds)
    destroyed = LogLine.create!(round: round, event_type: 'structure_destroyed', param1: 'resourcetower',
                                actor_steamid: 'STEAM_0:1:2', raw_text: 'destroyed',
                                created_at: round.start_time + 15.seconds)

    assign(:log_lines, [rt1, rt2, destroyed])

    render

    expect(rendered).to include('built a Resource Tower (1 total)')
    expect(rendered).to include('built a Resource Tower (2 total)')
    expect(rendered).to include('destroyed a Resource Tower (1 left)')
  end

  it 'shows "scanned the area" instead of "built a Scan"' do
    scan = LogLine.create!(round: round, event_type: 'structure_built', param1: 'scan',
                           actor_steamid: 'STEAM_0:1:1', raw_text: 'scan', created_at: round.start_time + 5.seconds)

    assign(:log_lines, [scan])

    render

    expect(rendered).to include('scanned the area')
    expect(rendered).not_to include('built a Scan')
  end

  it 'adds a virtual "fully grown" hive marker 3 minutes after it starts growing, with a running hive count' do
    built = LogLine.create!(round: round, event_type: 'structure_built', param1: 'team_hive',
                            actor_steamid: 'STEAM_0:1:2', raw_text: 'built hive',
                            created_at: round.start_time + 60.seconds)

    assign(:log_lines, [built])

    render

    expect(rendered).to include('started growing a Hive, ready in 3:00')
    expect(rendered).to include('A Hive is fully grown (1 hive total)')
  end

  it 'cancels the virtual hive marker and skips the count when a growing hive is destroyed first' do
    built = LogLine.create!(round: round, event_type: 'structure_built', param1: 'team_hive',
                            actor_steamid: 'STEAM_0:1:2', raw_text: 'built hive',
                            created_at: round.start_time + 60.seconds)
    destroyed = LogLine.create!(round: round, event_type: 'structure_destroyed', param1: 'team_hive',
                                actor_steamid: 'STEAM_0:1:1', raw_text: 'killed hive',
                                created_at: round.start_time + 90.seconds)

    assign(:log_lines, [built, destroyed])

    render

    expect(rendered).to include('destroyed a Hive before it finished growing')
    expect(rendered).not_to include('fully grown')
  end

  it 'shows the remaining hive count when a fully grown hive is destroyed' do
    built = LogLine.create!(round: round, event_type: 'structure_built', param1: 'team_hive',
                            actor_steamid: 'STEAM_0:1:2', raw_text: 'built hive',
                            created_at: round.start_time + 10.seconds)
    destroyed = LogLine.create!(round: round, event_type: 'structure_destroyed', param1: 'team_hive',
                                actor_steamid: 'STEAM_0:1:1', raw_text: 'killed hive',
                                created_at: round.start_time + 5.minutes)

    assign(:log_lines, [built, destroyed])

    render

    expect(rendered).to include('A Hive is fully grown (1 hive total)')
    expect(rendered).to include('destroyed a Hive (0 hives left)')
  end

  it 'handles destroying a hive with no matching build in this log window (e.g. a pre-existing home hive)' do
    destroyed = LogLine.create!(round: round, event_type: 'structure_destroyed', param1: 'team_hive',
                                actor_steamid: 'STEAM_0:1:1', raw_text: 'killed hive',
                                created_at: round.start_time + 5.minutes)

    assign(:log_lines, [destroyed])

    expect { render }.not_to raise_error
    expect(rendered).to include('destroyed a Hive')
  end

  it 'synthesizes a Round ended marker from the Round record when log lines exist but none say round_end' do
    kill = LogLine.create!(round: round, event_type: 'kill', param1: 'AlienOne', param2: 'machinegun',
                           actor_steamid: 'STEAM_0:1:1', target_steamid: 'STEAM_0:1:2',
                           raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                           created_at: round.start_time + 5.seconds)

    assign(:log_lines, [kill])

    render

    expect(rendered).to include('Round ended')
    expect(rendered).to include('Marines win')
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

  it 'shows separate team tables above the timeline with player identities and alien round statistics' do
    create(:user, steamid: 'STEAM_0:1:2', username: 'RegisteredAlien', country: 'FI')
    Rounder.create!(round: round, steamid: 'STEAM_0:1:3', team: Rounder::TEAM_ALIENS, share: 0.25)
    kill1 = LogLine.create!(round: round, event_type: 'kill', param1: 'MarineOne', param2: 'bitegun',
                            actor_steamid: 'STEAM_0:1:2', target_steamid: 'STEAM_0:1:1',
                            raw_text: "#{player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team')} killed " \
                                      "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} with \"bitegun\"",
                            created_at: round.start_time + 5.seconds)
    kill2 = LogLine.create!(round: round, event_type: 'kill', param1: 'MarineOne', param2: 'bitegun',
                            actor_steamid: 'STEAM_0:1:2', target_steamid: 'STEAM_0:1:1',
                            raw_text: "#{player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team')} killed " \
                                      "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} with \"bitegun\"",
                            created_at: round.start_time + 10.seconds)
    alien_death = LogLine.create!(round: round, event_type: 'kill', param1: 'AlienTwo', param2: 'machinegun',
                                  actor_steamid: 'STEAM_0:1:1', target_steamid: 'STEAM_0:1:3',
                                  raw_text: "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} killed " \
                        "#{player_raw('AlienTwo', 'STEAM_0:1:3', 'alien1team')} with \"machinegun\"",
                                  created_at: round.start_time + 12.seconds)
    tower = LogLine.create!(round: round, event_type: 'structure_destroyed', param1: 'resourcetower',
                            actor_steamid: 'STEAM_0:1:2', raw_text: 'destroyed RT',
                            created_at: round.start_time + 15.seconds)
    gorge = LogLine.create!(round: round, event_type: 'role_change', param1: 'gorge',
                            actor_steamid: 'STEAM_0:1:2', raw_text: player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team'),
                            created_at: round.start_time + 20.seconds)
    fade = LogLine.create!(round: round, event_type: 'role_change', param1: 'fade',
                           actor_steamid: 'STEAM_0:1:2', raw_text: player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team'),
                           created_at: round.start_time + 25.seconds)

    assign(:log_lines, [kill1, kill2, alien_death, tower, gorge, fade])

    render

    expect(rendered).to include('Marines')
    expect(rendered).to include('Aliens')
    expect(rendered).to include('<th>In-game name</th>')
    expect(rendered).to include('<th>ENSL username</th>')
    expect(rendered).to include('<th>Steam ID</th>')
    expect(rendered).to include('<th>K/D</th>')
    expect(rendered).to include('<th>RTs</th>')
    expect(rendered).to include('<th>Res</th>')
    expect(rendered).to include('flag-fi')
    expect(rendered).to include('RegisteredAlien')
    expect(rendered).to match(/round-full__ensl-identity.*?flag-fi.*?RegisteredAlien/m)
    expect(rendered).to include('0:1:2')
    expect(rendered).not_to include('>STEAM_0:1:2</td>')
    expect(rendered).to match(%r{AlienOne.*?<td>2</td>.*?<td>0</td>.*?<td>-</td>.*?<td>1</td>.*?<td>60</td>}m)
    expect(rendered.index('AlienOne')).to be < rendered.index('AlienTwo')
    expect(rendered.index('<h2>Players</h2>')).to be < rendered.index('<h2>Timeline</h2>')
  end

  it 'puts a player in the Players table by Rounder#team as-is, even when it disagrees with raw_text ' \
     '(by design -- real round 542 had several rounders permanently mismarked; that should stay visible)' do
    # Rounder says STEAM_0:1:2 is a MARINE, but every in-round log line has
    # them on alien1team -- the Marines table must still list them, matching
    # the (wrong) Rounder data, so the mismatch is visible for fixing upstream.
    Rounder.where(round: round, steamid: 'STEAM_0:1:2').update!(team: Rounder::TEAM_MARINES)

    kill = LogLine.create!(round: round, event_type: 'kill', param1: 'MarineOne', param2: 'bitegun',
                           actor_steamid: 'STEAM_0:1:2', target_steamid: 'STEAM_0:1:1',
                           raw_text: "#{player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team')} killed " \
                                     "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} with \"bitegun\"",
                           created_at: round.start_time + 5.seconds)

    assign(:log_lines, [kill])

    render

    aliens_table = rendered[%r{<h3>Aliens</h3>.*?</table>}m]
    marines_table = rendered[%r{<h3>Marines</h3>.*?</table>}m]
    expect(marines_table).to include('AlienOne')
    expect(aliens_table).not_to include('AlienOne')
  end

  it 'links a player name to their ENSL profile when the steamid matches a registered user' do
    user = create(:user, steamid: 'STEAM_0:1:1', username: 'RegisteredMarine')

    assign(:log_lines, [])

    render

    expect(rendered).to include(user_path(user))
    expect(rendered).to include('RegisteredMarine')
  end
end
