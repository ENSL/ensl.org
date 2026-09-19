# frozen_string_literal: true

# Renders a client-side sortable HTML table (see
# app/javascript/controllers/sortable_table.js). Every analysis listing
# (player rankings, and future ones like map balance) shares this instead of
# hand-rolling its own <table> markup, so adding a new listing is just a
# columns/rows definition + this one call.
module AnalysisHelper
  TECH_REQUIREMENT_TREE = {
    'start' => %w[arms_lab observatory armory turret_factory],
    'arms_lab' => %w[research_armorl1 research_weaponsl1 research_catalysts],
    'research_armorl1' => %w[research_armorl2],
    'research_armorl2' => %w[research_armorl3],
    'research_weaponsl1' => %w[research_weaponsl2],
    'research_weaponsl2' => %w[research_weaponsl3],
    'observatory' => %w[research_motiontracking research_phasetech],
    'armory' => %w[research_advarmory research_grenades],
    'turret_factory' => %w[research_electrical research_advturretfactory],
    'research_advarmory' => %w[proto_lab],
    'proto_lab' => %w[research_jetpacks research_heavyarmor]
  }.freeze
  TECH_REQUIREMENT_BUILDINGS = {
    'arms_lab' => { label: 'Arms Lab', icon: 'arms_lab' },
    'observatory' => { label: 'Observatory', icon: 'observatory' },
    'armory' => { label: 'Armory', icon: 'armory' },
    'proto_lab' => { label: 'Prototype Lab', icon: 'proto_lab' },
    'turret_factory' => { label: 'Turret Factory', icon: 'turret_factory' }
  }.freeze
  ALIEN_CHAMBER_ICONS = {
    'defensechamber' => '/images/ns1/640alienupgradecategories_0.png',
    'movementchamber' => '/images/ns1/640alienupgradecategories_2.png',
    'sensorychamber' => '/images/ns1/640alienupgradecategories_3.png'
  }.freeze
  ALIEN_STRATEGY_ACTIONS = {
    'skulk' => { label: 'Skulk', icon: 'skulk.png' },
    'gorge' => { label: 'Gorge', icon: 'gorge.png' },
    'lerk' => { label: 'Lerk', icon: 'lerk.png' },
    'fade' => { label: 'Fade', icon: 'fade.png' },
    'onos' => { label: 'Onos', icon: 'onos.png' },
    'rt' => { label: 'Alien Resource Tower', icon: '640alienupgradecategories_4.png' },
    'dc' => { label: 'Defense Chamber', icon: 'defensechamber.png' },
    'mc' => { label: 'Movement Chamber', icon: 'movementchamber.png' },
    'oc' => { label: 'Offense Chamber', icon: 'offensechamber.png' },
    'sc' => { label: 'Sensory Chamber', icon: 'sensorychamber.png' },
    'hive' => { label: 'Hive', icon: '640alienupgradecategories_5.png' }
  }.freeze

  # columns: array of hashes, each with:
  #   key         - symbol used to look up the raw value in each row hash
  #   label       - column header text
  #   type        - :string (default) or :number; controls sort comparison
  #   tooltip     - optional plain-text explanation shown when hovering the header
  #   sort_value  - optional proc(raw_value) -> comparable value (defaults to raw_value)
  #   format      - optional proc(raw_value) -> displayed value (defaults to raw_value)
  # rows: array of hashes, each keyed by every column's :key
  def sortable_table(columns:, rows:, id: nil, default_sort: nil, default_direction: :ascending)
    locals = { columns: columns, rows: rows, id: id, default_sort: default_sort,
               default_direction: default_direction }
    render partial: 'analysis/sortable_table', locals: locals
  end

  # Renders a MarineTechPathQuery path (raw `research_*` keys) as an arrow-
  # separated chain of icon + display name, reusing the same lookup tables
  # the round timeline built up from real log samples.
  def tech_path_display(path)
    steps = path.map do |research|
      icon = RoundsHelper::ROUND_TIMELINE_ICON_NAMES[research]
      if icon
        image = image_tag(tech_icon_path(icon), class: 'round-timeline-icon', alt: '',
                                                title: tech_path_research_name(research))
      end
      tag.span(safe_join([image, tech_path_research_name(research)].compact), class: 'tech-path-step')
    end
    safe_join(steps, tag.span(' → ', class: 'tech-path-arrow'))
  end

  def tech_path_research_name(research)
    RoundsHelper::ROUND_TIMELINE_RESEARCH_NAMES[research] ||
      RoundsHelper::ROUND_TIMELINE_STRUCTURE_NAMES[research] ||
      research.to_s.sub(/\Aresearch_/, '').humanize
  end

  # Plain-text version of the same path, used as the client-side sort key.
  def tech_path_label(path)
    path.map { |research| tech_path_research_name(research) }.join(' > ')
  end

  def alien_strategy_role_display(path)
    path = ['skulk'] if path == ['none']

    actions = path.chunk_while { |action, next_action| action == next_action }.map do |group|
      action = group.first
      details = ALIEN_STRATEGY_ACTIONS[action]
      count = tag.sup("x#{group.size}", class: 'alien-strategy-action__count') if group.size > 1
      next tag.span(safe_join([action.upcase, count].compact), class: 'alien-strategy-action__fallback') unless details

      image = image_tag(
        tech_icon_path(details[:icon]),
        class: 'alien-strategy-action__icon',
        alt: details[:label],
        title: details[:label]
      )
      tag.span(safe_join([image, count].compact),
               class: 'alien-strategy-action', title: details[:label])
    end
    safe_join(actions, tag.span('›', class: 'alien-strategy-role__arrow', aria: { hidden: true }))
  end

  def alien_strategy_win_style(win_ratio)
    hue = (win_ratio.clamp(0, 100) * 1.2).round
    "--win-hue: #{hue}"
  end

  def alien_strategy_duration(seconds)
    return '—' unless seconds

    duration = seconds.to_i
    format('%<minutes>d:%<seconds>02d', minutes: duration / 60, seconds: duration % 60)
  end

  def tech_tree_diagram(paths)
    node_ids = paths.each_with_index.to_h { |row, index| [row[:path], "tech#{index}"] }
    lines = ['flowchart LR', 'start((Start))']

    paths.each do |row|
      win_rate = "#{number_with_precision(row[:win_ratio], precision: 1)}%"
      lines << %(#{node_ids[row[:path]]}["#{win_rate}"])

      path = row[:path]
      source = path.length == 1 ? 'start' : node_ids[path.first(path.length - 1)]
      lines << "#{source} --> #{node_ids[path]}"
    end

    lines << 'classDef start fill:#0e4d78,stroke:#0e4d78,color:#ffffff'
    lines << 'classDef tech fill:transparent,stroke:transparent,color:#0e4d78'
    lines << 'class start start'
    lines << "class #{node_ids.values.join(',')} tech"
    lines.join("\n")
  end

  def tech_tree_icons(paths)
    paths.each_with_index.to_h do |row, index|
      research = row[:path].last
      icon_name = RoundsHelper::ROUND_TIMELINE_ICON_NAMES[research]
      icon = ALIEN_CHAMBER_ICONS[research] || (tech_icon_path(icon_name) if icon_name)
      ["tech#{index}", { icon: icon, label: tech_path_research_name(research), rounds: row[:rounds],
                         reachRate: row[:reach_rate], winRatio: row[:win_ratio] }]
    end
  end

  def tech_requirement_tree_diagram
    lines = ['flowchart TB', 'start((Start))']
    nodes = (TECH_REQUIREMENT_TREE.keys + TECH_REQUIREMENT_TREE.values.flatten).uniq - ['start']
    nodes.each { |node| lines << %(#{node}[" "]) }
    TECH_REQUIREMENT_TREE.each do |source, targets|
      targets.each { |target| lines << "#{source} --> #{target}" }
    end
    lines << 'classDef start fill:#0e4d78,stroke:#0e4d78,color:#ffffff'
    lines << 'classDef building fill:transparent,stroke:transparent,color:transparent'
    lines << 'classDef research fill:transparent,stroke:transparent,color:transparent'
    lines << 'class start start'
    lines << 'class arms_lab,observatory,armory,proto_lab,turret_factory building'
    research_nodes = %w[
      research_armorl1 research_armorl2 research_armorl3 research_weaponsl1 research_weaponsl2 research_weaponsl3
      research_catalysts research_motiontracking research_phasetech research_grenades research_jetpacks
      research_heavyarmor research_electrical research_advturretfactory research_advarmory
    ].join(',')
    lines << "class #{research_nodes} research"
    lines.join("\n")
  end

  def tech_requirement_tree_nodes(paths, rounds_analysed, min_rounds: 1)
    nodes = (TECH_REQUIREMENT_TREE.keys + TECH_REQUIREMENT_TREE.values.flatten).uniq
    nodes.index_with do |node|
      icon = TECH_REQUIREMENT_BUILDINGS.dig(node, :icon) || RoundsHelper::ROUND_TIMELINE_ICON_NAMES[node]
      { label: tech_requirement_tree_label(node), icon: icon ? tech_icon_path(icon) : nil,
        stats: tech_requirement_tree_stats(node, paths, rounds_analysed, min_rounds: min_rounds),
        parents: tech_requirement_parents(node), children: TECH_REQUIREMENT_TREE.fetch(node, []) }
    end
  end

  private

  def tech_icon_path(icon)
    "/images/ns1/#{icon.end_with?('.png') ? icon : "#{icon}.gif"}"
  end

  def tech_requirement_tree_label(node)
    TECH_REQUIREMENT_BUILDINGS.dig(node, :label) || tech_path_research_name(node)
  end

  def tech_requirement_tree_stats(research, paths, rounds_analysed, min_rounds:)
    return nil unless research.start_with?('research_')

    positions = (1..3).filter_map do |position|
      rows = paths.select { |row| row[:path].length == position && row[:path].last == research }
      tech_requirement_tree_result(rows, rounds_analysed, position, min_rounds: min_rounds)
    end
    overall_rows = paths.select { |row| row[:path].last == research }
    next_choices = tech_requirement_next_choices(paths, research, rounds_analysed, min_rounds)

    { overall: tech_requirement_tree_result(overall_rows, rounds_analysed, min_rounds: min_rounds),
      positions: positions,
      next_choices: next_choices }
  end

  def tech_requirement_next_choices(paths, research, rounds_analysed, min_rounds)
    rows = paths.select { |row| row[:path].length > 1 && row[:path][-2] == research }
    groups = rows.group_by { |row| row[:path].last }
    results = groups.filter_map do |next_research, next_rows|
      result = tech_requirement_tree_result(next_rows, rounds_analysed, min_rounds: min_rounds)
      result&.merge(key: tech_requirement_tree_node_id(next_research), label: tech_path_research_name(next_research))
    end
    results.max_by(5) { |result| [result[:win_ratio], result[:rounds]] }
  end

  def tech_requirement_tree_result(rows, rounds_analysed, position = nil, min_rounds:)
    rounds = rows.sum { |row| row[:rounds] }
    return if rounds < min_rounds

    wins = rows.sum { |row| row[:wins] }
    { position: position, rounds: rounds, reach_rate: rounds * 100.0 / rounds_analysed,
      win_ratio: wins * 100.0 / rounds }
  end

  def tech_requirement_parents(node)
    TECH_REQUIREMENT_TREE.filter_map { |parent, children| parent if children.include?(node) }
  end

  def tech_requirement_tree_node_id(research)
    research
  end
end
