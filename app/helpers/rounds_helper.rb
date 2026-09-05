# frozen_string_literal: true

# Builds the round timeline shown on rounds/show -- a vertically ordered,
# human-readable list of LogLine events (marines on the left, aliens on the
# right, system/neutral events centered) where the vertical gap between two
# events is proportional to how much time actually passed between them.
#
# Display names/weapon-to-team lore below were reverse-engineered from real
# imported data (dev DB) and the legacy commented-out NS1 regex matchers at
# the bottom of app/models/log_line.rb, since event_type/param* have no
# fixed enum anywhere in Ruby (they come from the ensl_analysis Python
# pipeline) -- see /memories/repo/round-timeline.md for the raw samples.
module RoundsHelper
  # Ballpark total height (px) the whole timeline aims for, regardless of how
  # long the round actually ran -- the per-second scale is derived from this
  # so a 5-minute round and a 40-minute round both render at a readable size.
  ROUND_TIMELINE_TARGET_HEIGHT = 2400
  ROUND_TIMELINE_MIN_PX_PER_SECOND = 0.5
  ROUND_TIMELINE_MAX_PX_PER_SECOND = 5.0
  # Minimum vertical space enforced between two consecutive events so a burst
  # of near-simultaneous events (e.g. a multi-kill) doesn't render as an
  # illegible stack of overlapping cards.
  ROUND_TIMELINE_MIN_GAP = 58
  # How close together (seconds) consecutive commander item drops by the same
  # player need to be to get folded into one "dropped 3 medpacks..." entry.
  ROUND_TIMELINE_DROP_WINDOW = 6
  # Fixed NS1 rule: an (unbuilt) hive always takes exactly this long to finish
  # growing once an alien starts it -- nothing in the game can speed this up
  # or slow it down, so it's safe to predict a completion time for it.
  ROUND_TIMELINE_HIVE_GROW_TIME = 3.minutes

  # Matches a player token as it appears embedded in LogLine#raw_text, e.g.
  # `"jiriki<15><STEAM_0:1:1511705><marine1team>"` -- used both to recover
  # in-game nicknames (Rounder only stores steamid/team, not a name) and to
  # read the player's ACTUAL team at that instant (see round_timeline_side_for
  # -- Rounder#team is a single round-level summary that can be wrong for
  # players who hop teams before the round officially starts).
  ROUND_TIMELINE_PLAYER_RE = /"(.+?)<\d+><(STEAM_[\d:]+)><([^">]*)>"/

  ROUND_TIMELINE_STRUCTURE_NAMES = {
    'alienresourcetower' => 'Alien Resource Tower', 'defensechamber' => 'Defense Chamber',
    'movementchamber' => 'Movement Chamber', 'offensechamber' => 'Offense Chamber',
    'sensorychamber' => 'Sensory Chamber', 'phasegate' => 'Phase Gate', 'resourcetower' => 'Resource Tower',
    'siegeturret' => 'Siege Turret', 'team_advarmory' => 'Advanced Armory',
    'team_advturretfactory' => 'Advanced Turret Factory', 'team_armory' => 'Armory',
    'team_armslab' => 'Arms Lab', 'team_command' => 'Command Station', 'team_hive' => 'Hive',
    'team_infportal' => 'Infantry Portal', 'team_observatory' => 'Observatory',
    'team_prototypelab' => 'Prototype Lab', 'team_turretfactory' => 'Turret Factory',
    'turret' => 'Sentry Turret', 'scan' => 'Scan'
  }.freeze

  # Structures worth tracking a running "how many does this team have" count
  # for (see round_timeline_adjust_count) -- team_hive is deliberately not
  # here, it gets its own dedicated (grow-time-aware) handling below.
  ROUND_TIMELINE_COUNTED_STRUCTURES = %w[
    resourcetower alienresourcetower defensechamber movementchamber offensechamber sensorychamber
  ].freeze

  # Dropped items/weapons -- also reported as "structure_built" by the NS1
  # engine, but grouped into combined "dropped N X, N Y" entries (see
  # round_timeline_items) instead of shown individually like real buildings.
  ROUND_TIMELINE_ITEM_NAMES = {
    'item_catalyst' => 'Catalyst Pack', 'item_genericammo' => 'Ammo Pack', 'item_health' => 'Medpack',
    'item_heavyarmor' => 'Heavy Armor', 'item_jetpack' => 'Jetpack', 'weapon_grenadegun' => 'Grenade Launcher',
    'weapon_heavymachinegun' => 'Heavy Machine Gun', 'weapon_mine' => 'Mine', 'weapon_shotgun' => 'Shotgun',
    'weapon_welder' => 'Welder'
  }.freeze

  ROUND_TIMELINE_RESEARCH_NAMES = {
    'research_advarmory' => 'Advanced Armory', 'research_advturretfactory' => 'Advanced Turret Factory',
    'research_armorl1' => 'Armor Level 1', 'research_armorl2' => 'Armor Level 2',
    'research_armorl3' => 'Armor Level 3', 'research_catalysts' => 'Catalysts',
    'research_distressbeacon' => 'Distress Beacon', 'research_electrical' => 'Electrical',
    'research_grenades' => 'Grenades', 'research_heavyarmor' => 'Heavy Armor', 'research_jetpacks' => 'Jetpacks',
    'research_motiontracking' => 'Motion Tracking', 'research_phasetech' => 'Phase Technology',
    'research_weaponsl1' => 'Weapons Level 1', 'research_weaponsl2' => 'Weapons Level 2',
    'research_weaponsl3' => 'Weapons Level 3'
  }.freeze

  ROUND_TIMELINE_ROLE_NAMES = {
    'soldier' => 'Marine', 'skulk' => 'Skulk', 'gorge' => 'Gorge', 'lerk' => 'Lerk', 'fade' => 'Fade',
    'onos' => 'Onos'
  }.freeze

  ROUND_PLAYER_LIFEFORM_COSTS = {
    'skulk' => 0, 'gorge' => 10, 'lerk' => 30, 'fade' => 50, 'onos' => 75
  }.freeze

  # param2 on a "kill" event -- either a real weapon, or (less obviously) the
  # name of the structure/environment that got the kill credit instead.
  ROUND_TIMELINE_WEAPON_NAMES = {
    'acidrocket' => 'Acid Rocket', 'bite2gun' => 'Bite', 'bitegun' => 'Bite', 'charge' => 'Charge',
    'claws' => 'Claws', 'devour' => 'Devour', 'divinewind' => 'Divine Wind', 'grenade' => 'Grenade',
    'handgrenade' => 'Hand Grenade', 'healingspray' => 'Healing Spray', 'heavymachinegun' => 'HMG',
    'item_mine' => 'Mine', 'knife' => 'Knife', 'leap' => 'Leap', 'machinegun' => 'LMG',
    'parasite' => 'Parasite', 'pistol' => 'Pistol', 'shotgun' => 'Shotgun', 'spitgunspit' => 'Spit',
    'sporegunprojectile' => 'Spores', 'swipe' => 'Swipe', 'welder' => 'Welder', 'world' => 'the environment'
  }.freeze

  # Returns an array of hashes (in chronological order) with the data needed
  # to position and render each event: :side, :top (px), :time_label, :description.
  def round_timeline_events(round, log_lines)
    return [] if log_lines.empty?

    context = {
      round: round,
      names: round_timeline_names(log_lines),
      rounders: round.rounders.index_by(&:steamid)
    }
    items = round_timeline_items(log_lines, context)
    return [] if items.empty?

    reference_time = round.start_time || items.first[:created_at]
    px_per_second = round_timeline_scale(round, items)

    top = -Float::INFINITY
    items.map do |item|
      top = [(item[:created_at] - reference_time) * px_per_second, top + ROUND_TIMELINE_MIN_GAP].max
      { side: item[:side], top: top.round, time_label: round_timeline_time_label(item[:created_at] - reference_time),
        description: item[:description] }
    end
  end

  # Total container height needed to fit every positioned event.
  def round_timeline_height(events)
    return 0 if events.empty?

    events.last[:top] + 80
  end

  # steamid -> in-game nickname recovered from raw_text (see
  # ROUND_TIMELINE_PLAYER_RE). Public so the Players tables (rounds/show.html.erb)
  # can show a readable name even for a steamid with no linked ENSL user.
  def round_timeline_names(log_lines)
    names = {}
    log_lines.each do |log_line|
      log_line.raw_text.to_s.scan(ROUND_TIMELINE_PLAYER_RE) { |name, steamid, _team| names[steamid] = name }
    end
    names
  end

  # Display name for a Rounder in the Players tables -- a linked ENSL user
  # (clickable, via the existing namelink helper) wins over the raw in-game
  # nickname, which wins over falling all the way back to the steamid.
  def round_player_name(rounder, names_by_steamid)
    return namelink(rounder.user) if rounder.user

    names_by_steamid[rounder.steamid] || rounder.steamid
  end

  # Per-player totals shown above the timeline. Costs are recorded from each
  # alien lifeform role_change; structure events are deliberately excluded.
  def round_player_stats(rounders, log_lines)
    stats = rounders.index_by(&:steamid).transform_values do
      { kills: 0, deaths: 0, resource_towers: 0, resources_spent: 0 }
    end

    log_lines.each do |log_line|
      case log_line.event_type
      when 'kill'
        stats[log_line.actor_steamid][:kills] += 1 if stats.key?(log_line.actor_steamid)
        stats[log_line.target_steamid][:deaths] += 1 if stats.key?(log_line.target_steamid)
      when 'structure_destroyed'
        if %w[resourcetower alienresourcetower].include?(log_line.param1) && stats.key?(log_line.actor_steamid)
          stats[log_line.actor_steamid][:resource_towers] += 1
        end
      when 'role_change'
        cost = ROUND_PLAYER_LIFEFORM_COSTS[log_line.param1]
        stats[log_line.actor_steamid][:resources_spent] += cost if cost && stats.key?(log_line.actor_steamid)
      end
    end

    stats.each_value do |player_stats|
      player_stats[:kd_ratio] = if player_stats[:deaths].zero?
                                  Float::INFINITY
                                else
                                  player_stats[:kills].fdiv(player_stats[:deaths])
                                end
    end
  end

  private

  # Turns the ordered log lines into timeline items: gestate -> role_change
  # pairs fold into one "started evolving/upgrading" entry, bursts of nearby
  # commander item drops fold into one combined entry, routine respawns
  # (skulk, marine after death) are dropped entirely, hive growth gets a
  # virtual completion marker, and a couple of always-present synthetic
  # entries (team rosters, round end) are appended -- so the timeline reads
  # as a narrative instead of a raw event dump.
  def round_timeline_items(log_lines, context)
    state = {
      items: [], pending_drop: nil, gestating: {}, last_role: {}, growing_hives: [],
      structure_counts: Hash.new(0), round_end_seen: false
    }
    log_lines.each { |log_line| round_timeline_process_line(log_line, state, context) }
    round_timeline_flush_drop(state, context)
    state[:gestating].each_value { |gestate| state[:items] << round_timeline_evolve_item(gestate, nil, context) }
    round_timeline_finalize_hives(state, context)
    round_timeline_finalize_round_end(state, context)
    round_timeline_add_roster_items(state, context, log_lines)

    state[:items].sort_by { |item| item[:created_at] }
  end

  def round_timeline_process_line(log_line, state, context)
    return round_timeline_process_role_change(log_line, state, context) if log_line.event_type == 'role_change'
    return round_timeline_flush_drop(state, context) if log_line.event_type == 'join_team'
    return round_timeline_process_hive(log_line, state, context) if round_timeline_hive_event?(log_line)

    if log_line.event_type == 'structure_built' && ROUND_TIMELINE_ITEM_NAMES.key?(log_line.param1)
      round_timeline_accumulate_drop(log_line, state, context)
    else
      round_timeline_flush_drop(state, context)
      state[:round_end_seen] = true if log_line.event_type == 'round_end'
      state[:items] << round_timeline_plain_item(log_line, state, context)
    end
  end

  def round_timeline_hive_event?(log_line)
    log_line.param1 == 'team_hive' && %w[structure_built structure_destroyed].include?(log_line.event_type)
  end

  # role_change is handled outside the generic dispatch because it needs
  # cross-event memory (the actor's previous role) to detect a gestate's
  # eventual target role, an upgrade-in-place, and a commander stepping down.
  def round_timeline_process_role_change(log_line, state, context)
    actor_steamid = log_line.actor_steamid
    previous_role = state[:last_role][actor_steamid]
    state[:last_role][actor_steamid] = log_line.param1

    if log_line.param1 == 'gestate'
      round_timeline_flush_drop(state, context)
      state[:gestating][actor_steamid] = { line: log_line, previous_role: previous_role }
    elsif state[:gestating].key?(actor_steamid)
      round_timeline_flush_drop(state, context)
      gestate = state[:gestating].delete(actor_steamid)
      state[:items] << round_timeline_evolve_item(gestate, log_line.param1, context)
    elsif !round_timeline_respawn_role?(log_line.param1, previous_role)
      round_timeline_flush_drop(state, context)
      state[:items] << round_timeline_role_item(log_line, previous_role, context)
    end
  end

  # skulk and (non-chair) soldier are just what you respawn as after dying --
  # not narratively interesting on their own, unlike an actual evolve/upgrade
  # or a commander stepping down from the chair back into a marine.
  def round_timeline_respawn_role?(role, previous_role)
    return true if role == 'skulk'

    role == 'soldier' && previous_role != 'commander'
  end

  def round_timeline_role_item(log_line, previous_role, context)
    actor = round_timeline_name(log_line.actor_steamid, context)
    {
      created_at: log_line.created_at,
      side: round_timeline_side_for(log_line.actor_steamid, nil, context, raw_text: log_line.raw_text),
      description: round_timeline_role_description(actor, log_line.param1, previous_role)
    }
  end

  def round_timeline_role_description(actor, role, previous_role)
    return "#{actor} took command" if role == 'commander'
    return "#{actor} left the chair" if role == 'soldier' && previous_role == 'commander'

    "#{actor} became #{with_article(ROUND_TIMELINE_ROLE_NAMES[role] || role.to_s.humanize)}"
  end

  def round_timeline_evolve_item(gestate, target_role, context)
    gestate_line = gestate[:line]
    actor = round_timeline_name(gestate_line.actor_steamid, context)
    {
      created_at: gestate_line.created_at,
      side: round_timeline_side_for(gestate_line.actor_steamid, nil, context, raw_text: gestate_line.raw_text),
      description: round_timeline_evolve_description(actor, target_role, gestate[:previous_role])
    }
  end

  # Alien evolution and an in-place "upgrade" (re-selecting the SAME lifeform
  # to change adaptations) both go through the same gestate -> role_change
  # sequence -- the only way to tell them apart is whether the resolved role
  # differs from what the actor already was before gestating.
  def round_timeline_evolve_description(actor, target_role, previous_role)
    return "#{actor} started evolving" unless target_role
    return "#{actor} started upgrading" if target_role == previous_role

    "#{actor} started evolving to #{ROUND_TIMELINE_ROLE_NAMES[target_role] || target_role.humanize}"
  end

  def round_timeline_flush_drop(state, context)
    item = round_timeline_drop_group_item(state[:pending_drop], context)
    state[:items] << item if item
    state[:pending_drop] = nil
  end

  def round_timeline_accumulate_drop(log_line, state, context)
    drop = state[:pending_drop]
    if drop && drop[:actor_steamid] == log_line.actor_steamid &&
       (log_line.created_at - drop[:last_time]) <= ROUND_TIMELINE_DROP_WINDOW
      drop[:counts][log_line.param1] += 1
      drop[:last_time] = log_line.created_at
    else
      round_timeline_flush_drop(state, context)
      state[:pending_drop] = {
        actor_steamid: log_line.actor_steamid, created_at: log_line.created_at, last_time: log_line.created_at,
        raw_text: log_line.raw_text, counts: Hash.new(0).merge(log_line.param1 => 1)
      }
    end
  end

  def round_timeline_drop_group_item(drop, context)
    return nil unless drop

    parts = drop[:counts].map do |type, count|
      name = ROUND_TIMELINE_ITEM_NAMES[type]
      count == 1 ? "1 #{name}" : "#{count} #{name.pluralize}"
    end
    {
      created_at: drop[:created_at],
      side: round_timeline_side_for(drop[:actor_steamid], nil, context, raw_text: drop[:raw_text]),
      description: "#{round_timeline_name(drop[:actor_steamid], context)} dropped #{parts.to_sentence}"
    }
  end

  # A hive takes a fixed 3 minutes to finish growing once started -- track it
  # so a "should be fully grown by now" marker can be synthesized (virtual,
  # never written to the DB) unless it's destroyed before that time comes.
  def round_timeline_process_hive(log_line, state, context)
    round_timeline_flush_drop(state, context)
    if log_line.event_type == 'structure_built'
      round_timeline_hive_built_item(log_line, state, context)
    else
      round_timeline_hive_destroyed_item(log_line, state, context)
    end
  end

  def round_timeline_hive_built_item(log_line, state, context)
    predicted_at = log_line.created_at + ROUND_TIMELINE_HIVE_GROW_TIME
    state[:growing_hives] << predicted_at
    actor = round_timeline_name(log_line.actor_steamid, context)
    state[:items] << {
      created_at: log_line.created_at,
      side: round_timeline_side_for(log_line.actor_steamid, nil, context, raw_text: log_line.raw_text),
      description: "#{actor} started growing a Hive, ready in 3:00"
    }
  end

  def round_timeline_hive_destroyed_item(log_line, state, context)
    actor = round_timeline_name(log_line.actor_steamid, context)
    side = round_timeline_side_for(log_line.actor_steamid, nil, context, raw_text: log_line.raw_text)
    # FIFO: the earliest hive that hasn't finished growing yet is assumed to
    # be the one that just died (the log has no per-hive identity to match on).
    still_growing_index = state[:growing_hives].index { |predicted_at| predicted_at > log_line.created_at }

    description = if still_growing_index
                    state[:growing_hives].delete_at(still_growing_index)
                    "#{actor} destroyed a Hive before it finished growing"
                  else
                    # No pending "still growing" entry -- either this hive
                    # already finished growing (retroactively add its own
                    # "fully grown" marker/count now, since nothing else
                    # would have surfaced it) or it existed before this log
                    # window (e.g. a map's home hive, nothing to retroact).
                    round_timeline_hive_grew_item(state, context)
                    count = round_timeline_adjust_count(state, 'team_hive', -1)
                    "#{actor} destroyed a Hive (#{count} #{'hive'.pluralize(count)} left)"
                  end

    state[:items] << { created_at: log_line.created_at, side: side, description: description }
  end

  # A hive that grew to completion gets its own "fully grown" virtual marker
  # (and is only now added to the running total) at the time it actually
  # finished growing -- called both as soon as we discover it's already
  # complete (a later structure_destroyed with no still-growing match) and,
  # for hives that are never destroyed, once at the end of the real log.
  # There may be no matching build in this log window at all (e.g. a map's
  # home hive, already grown since before the round started) -- nothing to
  # mark or count then.
  def round_timeline_hive_grew_item(state, context)
    predicted_at = state[:growing_hives].shift
    return unless predicted_at

    round_end = context[:round].end_time
    return if round_end && predicted_at > round_end

    count = round_timeline_adjust_count(state, 'team_hive', 1)
    state[:items] << { created_at: predicted_at, side: 'neutral',
                       description: "A Hive is fully grown (#{count} #{'hive'.pluralize(count)} total)" }
  end

  # Any hive still growing when the real log lines run out either finished
  # growing (add the virtual marker, if that happens before the round ended)
  # or the round ended first (nothing to show).
  def round_timeline_finalize_hives(state, context)
    round_timeline_hive_grew_item(state, context) while state[:growing_hives].any?
  end

  # round_end LogLines are unreliable in the imported data (sometimes missing,
  # sometimes misattributed to the wrong round -- see /memories/repo/round-
  # timeline.md), so a "Round ended" marker is always synthesized from the
  # Round record itself unless a real one was already seen in this log.
  def round_timeline_finalize_round_end(state, context)
    return if state[:round_end_seen]

    round = context[:round]
    return unless round.end_time

    state[:items] << { created_at: round.end_time, side: 'neutral',
                       description: round_timeline_round_end_description(round) }
  end

  # Individual join_team spam (especially team-hopping while picking sides)
  # is suppressed entirely in favor of one roster line per side.
  def round_timeline_add_roster_items(state, context, log_lines)
    reference = context[:round].start_time || log_lines.first.created_at
    marines, aliens = context[:rounders].values.partition { |rounder| rounder.team == Rounder::TEAM_MARINES }
    state[:items] << round_timeline_roster_item(marines, 'marine', 'Marines', reference + 0.1, context) if marines.any?
    state[:items] << round_timeline_roster_item(aliens, 'alien', 'Aliens', reference + 0.2, context) if aliens.any?
  end

  def round_timeline_roster_item(rounders, side, label, created_at, context)
    names = rounders.map { |rounder| round_timeline_name(rounder.steamid, context) }
    { created_at: created_at, side: side, description: "#{label}: #{names.to_sentence}" }
  end

  def round_timeline_scale(round, items)
    duration = if round.start_time && round.end_time
                 round.end_time - round.start_time
               else
                 items.last[:created_at] - items.first[:created_at]
               end
    duration = 1.0 if duration.to_f <= 0

    (ROUND_TIMELINE_TARGET_HEIGHT / duration.to_f)
      .clamp(ROUND_TIMELINE_MIN_PX_PER_SECOND, ROUND_TIMELINE_MAX_PX_PER_SECOND)
  end

  # The specific log line's raw_text (the player's team suffix at THAT
  # instant) is trusted over Rounder#team, which is a single round-level
  # summary that can be wrong for players who hop teams before the round
  # officially starts (real example: round 1130, actor ends up permanently
  # marked "alien" for the round because of an early pre-round team pick,
  # even though every in-round log line shows them on marine1team).
  def round_timeline_side_for(actor_steamid, target_steamid, context, raw_text: nil)
    round_timeline_team_from_raw(raw_text, actor_steamid) ||
      round_timeline_team_from_raw(raw_text, target_steamid) ||
      round_timeline_rounder_side(actor_steamid, context) ||
      round_timeline_rounder_side(target_steamid, context) ||
      'neutral'
  end

  def round_timeline_team_from_raw(raw_text, steamid)
    return nil if raw_text.blank? || steamid.blank?

    raw_text.scan(ROUND_TIMELINE_PLAYER_RE) do |_, sid, team|
      next unless sid == steamid

      return 'marine' if team.to_s.start_with?('marine')
      return 'alien' if team.to_s.start_with?('alien')
    end
    nil
  end

  def round_timeline_rounder_side(steamid, context)
    case context[:rounders][steamid]&.team
    when Rounder::TEAM_MARINES then 'marine'
    when Rounder::TEAM_ALIENS then 'alien'
    end
  end

  def round_timeline_time_label(seconds)
    seconds = seconds.to_i
    format('%<minutes>02d:%<seconds>02d', minutes: seconds / 60, seconds: seconds % 60)
  end

  # A registered ENSL username (if the steamid is linked) wins over the raw
  # in-game nickname, which wins over falling all the way back to the steamid.
  def round_timeline_name(steamid, context)
    return nil if steamid.blank?

    rounder = context[:rounders][steamid]
    return rounder.user.username if rounder&.user

    context[:names][steamid] || steamid
  end

  def with_article(noun)
    "#{noun.to_s.match?(/\A[aeiou]/i) ? 'an' : 'a'} #{noun}"
  end

  def round_timeline_plain_item(log_line, state, context)
    {
      created_at: log_line.created_at,
      side: round_timeline_side_for(log_line.actor_steamid, log_line.target_steamid, context,
                                    raw_text: log_line.raw_text),
      description: round_timeline_description(log_line, state, context)
    }
  end

  def round_timeline_description(log_line, state, context)
    actor = round_timeline_name(log_line.actor_steamid, context)

    round_timeline_player_description(log_line, actor, context) ||
      round_timeline_structure_description(log_line, actor, state) ||
      round_timeline_system_description(log_line, context) ||
      log_line.raw_text.to_s
  end

  def round_timeline_player_description(log_line, actor, context)
    case log_line.event_type
    when 'kill' then round_timeline_kill_description(actor, log_line, context)
    when 'disconnect' then "#{actor} disconnected"
    end
  end

  def round_timeline_structure_description(log_line, actor, state)
    case log_line.event_type
    when 'structure_built' then round_timeline_built_description(log_line, actor, state)
    when 'structure_destroyed' then round_timeline_destroyed_description(log_line, actor, state, 'destroyed')
    when 'recycle' then round_timeline_destroyed_description(log_line, actor, state, 'recycled')
    when 'research_start'
      research = ROUND_TIMELINE_RESEARCH_NAMES[log_line.param1] || log_line.param1.to_s.humanize
      "#{actor} started researching #{research}"
    when 'research_cancel' then "#{actor} cancelled a research order"
    end
  end

  # "scan" is a commander ability activation, not a placed structure, even
  # though the NS1 engine logs it identically to a real "structure_built".
  def round_timeline_built_description(log_line, actor, state)
    return "#{actor} scanned the area" if log_line.param1 == 'scan'

    name = round_timeline_structure_name(log_line.param1)
    return "#{actor} built #{with_article(name)}" unless ROUND_TIMELINE_COUNTED_STRUCTURES.include?(log_line.param1)

    count = round_timeline_adjust_count(state, log_line.param1, 1)
    "#{actor} built #{with_article(name)} (#{count} total)"
  end

  def round_timeline_destroyed_description(log_line, actor, state, verb)
    name = round_timeline_structure_name(log_line.param1)
    return "#{actor} #{verb} #{with_article(name)}" unless ROUND_TIMELINE_COUNTED_STRUCTURES.include?(log_line.param1)

    count = round_timeline_adjust_count(state, log_line.param1, -1)
    "#{actor} #{verb} #{with_article(name)} (#{count} left)"
  end

  def round_timeline_adjust_count(state, type, delta)
    state[:structure_counts][type] = [state[:structure_counts][type] + delta, 0].max
  end

  def round_timeline_system_description(log_line, context)
    case log_line.event_type
    when 'round_start' then 'Round started'
    when 'round_end' then round_timeline_round_end_description(context[:round])
    end
  end

  def round_timeline_structure_name(type)
    ROUND_TIMELINE_STRUCTURE_NAMES[type] || type.to_s.tr('_', ' ')
  end

  def round_timeline_kill_description(actor, log_line, context)
    target = round_timeline_name(log_line.target_steamid, context) || log_line.param1
    weapon = ROUND_TIMELINE_WEAPON_NAMES[log_line.param2] || ROUND_TIMELINE_STRUCTURE_NAMES[log_line.param2] ||
             log_line.param2.to_s.tr('_', ' ')
    "#{actor} killed #{target} with #{weapon}"
  end

  def round_timeline_round_end_description(round)
    winner = round.winner_s
    winner ? "Round ended \u2014 #{winner} win" : 'Round ended'
  end
end
