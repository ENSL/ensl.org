# frozen_string_literal: true

module Analysis
  # /analysis -- the "Stats" hub linked from the main navigation. Static
  # navigation page listing out each individual read-only listing (player
  # rankings, map balance, ...future ones); nothing dynamic to compute here,
  # each card just links to its own controller/action. Adding a new stats
  # page later is just a new entry in PAGES (plus its own controller/route).
  class HomeController < Analysis::BaseController
    PAGES = [
      {
        title: 'NS1 Rankings',
        description: 'NS1 skill ratings and win/loss records for every tracked player. Sort by any column.',
        icon: 'trophy',
        path_helper: :analysis_users_path
      },
      {
        title: 'NS1 Class performance',
        description: 'Compare each player with every NS1 class, independent of map, team, and side.',
        icon: 'crosshairs',
        path_helper: :analysis_classes_path
      },
      {
        title: 'Team rankings',
        description: 'OpenSkill ratings, records and tournament wins for every team, NS1 and NS2 separately.',
        icon: 'users',
        path_helper: :analysis_teams_path
      },
      {
        title: 'NS1 Map balance',
        description: 'NS1 marine vs alien win rates for every map currently in rotation.',
        icon: 'map',
        path_helper: :analysis_maps_path
      },
      {
        title: 'NS1 Gather Rankings',
        description: 'Pick-order-based NS1 gather rankings, including a draft-only OpenSkill score.',
        icon: 'sort-numeric-down',
        path_helper: :analysis_pick_orders_path
      },
      {
        title: 'NS1 Marine tech paths',
        description: 'Which NS1 marine opening research orders win the most, straight from the round logs.',
        icon: 'sitemap',
        path_helper: :analysis_tech_paths_path
      },
      {
        title: 'NS1 Round length',
        description: 'How marine and alien win rates shift with round length, overall or on a single map.',
        icon: 'stopwatch',
        path_helper: :analysis_round_lengths_path
      },
      {
        title: 'NS1 Play times',
        description: 'When rounds actually get played: a day-of-week by hour-of-day activity heatmap.',
        icon: 'calendar-alt',
        path_helper: :analysis_activity_path
      },
      {
        title: 'Round Data Over Time',
        description: 'Explore how imported NS1 rounds are distributed across months, quarters, and years.',
        icon: 'bar-chart',
        path_helper: :statistics_rounds_path
      }
    ].freeze

    def index
      @pages = PAGES
      render layout: 'full'
    end
  end
end
