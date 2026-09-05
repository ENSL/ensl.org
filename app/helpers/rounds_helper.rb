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

  # Matches a player token as it appears embedded in LogLine#raw_text, e.g.
  # `"jiriki<15><STEAM_0:1:1511705><marine1team>"` -- used to recover in-game
  # nicknames, since Rounder only stores steamid/team, not a name.
  ROUND_TIMELINE_PLAYER_RE = /"(.+?)<\d+><(STEAM_[\d:]+)><[^">]*>"/

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
      rounders: round.rounders.includes(:user).index_by(&:steamid)
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

  private

  # Recovers in-game nicknames from raw_text (see ROUND_TIMELINE_PLAYER_RE) --
  # Rounder only knows steamid/team, not the name the player actually used.
  def round_timeline_names(log_lines)
    names = {}
    log_lines.each do |log_line|
      log_line.raw_text.to_s.scan(ROUND_TIMELINE_PLAYER_RE) { |name, steamid| names[steamid] = name }
    end
    names
  end

  # Folds gestate -> role_change pairs into one "started evolving to X" entry,
  # and bursts of nearby commander item drops into one combined entry, so the
  # timeline reads as a narrative instead of a raw event dump.
  def round_timeline_items(log_lines, context)
    state = { items: [], pending_drop: nil, gestating: {} }
    log_lines.each { |log_line| round_timeline_process_line(log_line, state, context) }
    round_timeline_flush_drop(state, context)
    state[:gestating].each_value { |g| state[:items] << round_timeline_evolve_item(g, nil, context) }

    state[:items].sort_by { |item| item[:created_at] }
  end

  def round_timeline_process_line(log_line, state, context)
    if log_line.event_type == 'role_change' && log_line.param1 == 'gestate'
      round_timeline_flush_drop(state, context)
      state[:gestating][log_line.actor_steamid] = log_line
    elsif log_line.event_type == 'role_change' && state[:gestating].key?(log_line.actor_steamid)
      round_timeline_flush_drop(state, context)
      gestate_line = state[:gestating].delete(log_line.actor_steamid)
      state[:items] << round_timeline_evolve_item(gestate_line, log_line.param1, context)
    elsif log_line.event_type == 'structure_built' && ROUND_TIMELINE_ITEM_NAMES.key?(log_line.param1)
      round_timeline_accumulate_drop(log_line, state, context)
    else
      round_timeline_flush_drop(state, context)
      state[:items] << round_timeline_plain_item(log_line, context)
    end
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
      state[:pending_drop] = { actor_steamid: log_line.actor_steamid, created_at: log_line.created_at,
                               last_time: log_line.created_at, counts: Hash.new(0).merge(log_line.param1 => 1) }
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
      side: round_timeline_side_for(drop[:actor_steamid], nil, context),
      description: "#{round_timeline_name(drop[:actor_steamid], context)} dropped #{parts.to_sentence}"
    }
  end

  def round_timeline_evolve_item(gestate_line, target_role, context)
    actor = round_timeline_name(gestate_line.actor_steamid, context)
    description = if target_role
                    "#{actor} started evolving to #{ROUND_TIMELINE_ROLE_NAMES[target_role] || target_role.humanize}"
                  else
                    "#{actor} started evolving"
                  end
    { created_at: gestate_line.created_at, side: round_timeline_side_for(gestate_line.actor_steamid, nil, context),
      description: description }
  end

  def round_timeline_plain_item(log_line, context)
    {
      created_at: log_line.created_at,
      side: round_timeline_side_for(log_line.actor_steamid, log_line.target_steamid, context),
      description: round_timeline_description(log_line, context)
    }
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

  def round_timeline_side_for(actor_steamid, target_steamid, context)
    rounder = context[:rounders][actor_steamid] || context[:rounders][target_steamid]
    case rounder&.team
    when Rounder::TEAM_MARINES then 'marine'
    when Rounder::TEAM_ALIENS then 'alien'
    else 'neutral'
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

  def round_timeline_team_name(actor_steamid, context)
    case context[:rounders][actor_steamid]&.team
    when Rounder::TEAM_MARINES then 'Marines'
    when Rounder::TEAM_ALIENS then 'Aliens'
    end
  end

  def with_article(noun)
    "#{noun.to_s.match?(/\A[aeiou]/i) ? 'an' : 'a'} #{noun}"
  end

  def round_timeline_description(log_line, context)
    actor = round_timeline_name(log_line.actor_steamid, context)

    round_timeline_player_description(log_line, actor, context) ||
      round_timeline_structure_description(log_line, actor) ||
      round_timeline_system_description(log_line, context) ||
      log_line.raw_text.to_s
  end

  def round_timeline_player_description(log_line, actor, context)
    case log_line.event_type
    when 'kill' then round_timeline_kill_description(actor, log_line, context)
    when 'role_change' then round_timeline_role_description(actor, log_line.param1)
    when 'join_team'
      team_name = round_timeline_team_name(log_line.actor_steamid, context)
      team_name ? "#{actor} joined the #{team_name}" : "#{actor} joined a team"
    when 'disconnect' then "#{actor} disconnected"
    end
  end

  def round_timeline_structure_description(log_line, actor)
    structure = -> { with_article(round_timeline_structure_name(log_line.param1)) }

    case log_line.event_type
    when 'structure_built' then "#{actor} built #{structure.call}"
    when 'structure_destroyed' then "#{actor} destroyed #{structure.call}"
    when 'recycle' then "#{actor} recycled #{structure.call}"
    when 'research_start'
      research = ROUND_TIMELINE_RESEARCH_NAMES[log_line.param1] || log_line.param1.to_s.humanize
      "#{actor} started researching #{research}"
    when 'research_cancel' then "#{actor} cancelled a research order"
    end
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

  def round_timeline_role_description(actor, role)
    return "#{actor} took command" if role == 'commander'

    "#{actor} became #{with_article(ROUND_TIMELINE_ROLE_NAMES[role] || role.to_s.humanize)}"
  end

  def round_timeline_round_end_description(round)
    winner = round.winner_s
    winner ? "Round ended \u2014 #{winner} win" : 'Round ended'
  end
end
