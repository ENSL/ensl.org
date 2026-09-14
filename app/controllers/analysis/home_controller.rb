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
        title: 'NS1 Player rankings',
        description: 'NS1 skill ratings and win/loss records for every tracked player. Sort by any column.',
        icon: 'trophy',
        path_helper: :analysis_users_path
      },
      {
        title: 'NS1 Gather Rankings',
        description: 'Pick-order-based NS1 gather rankings, including a draft-only OpenSkill score.',
        icon: 'sort-numeric-down',
        path_helper: :analysis_pick_orders_path
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
        title: 'NS1 Class performance',
        description: 'Compare each player with every NS1 class, independent of map, team, and side.',
        icon: 'crosshairs',
        path_helper: :analysis_classes_path
      },
      {
        title: 'NS1 Marine Strategies',
        description: 'Which NS1 marine opening research orders win the most, straight from the round logs.',
        icon: 'sitemap',
        image: '/images/ns1/comm_icon.gif',
        category: :marine,
        links: [
          { label: 'Strategies', icon: 'list', path_helper: :analysis_tech_paths_path },
          { label: 'Graph', icon: 'project-diagram', path_helper: :analysis_tech_tree_path },
          { label: 'Tech tree', icon: 'sitemap', path_helper: :analysis_tech_requirements_path }
        ]
      },
      {
        title: 'NS1 Alien Strategies',
        description: 'Six-player alien role and build combinations, grouped by their opening actions and win rate.',
        icon: 'layer-group',
        image: '/images/ns1/hive_icon.gif',
        category: :alien,
        links: [
          { label: 'Strategies', icon: 'list', path_helper: :analysis_alien_strategies_path },
          { label: 'Graph', icon: 'project-diagram', path_helper: :analysis_alien_tech_tree_path }
        ]
      },
      {
        title: 'NS1 Round length',
        description: 'How marine and alien win rates shift with round length, overall or on a single map.',
        icon: 'stopwatch',
        path_helper: :analysis_round_lengths_path
      },
      {
        title: 'NS1 Round activity',
        description: 'Explore when rounds are played during a week and how the imported record has grown over time.',
        icon: 'calendar-alt',
        links: [
          { label: 'Weekly', icon: 'calendar-alt', path_helper: :analysis_activity_path },
          { label: 'Annual', icon: 'bar-chart', path_helper: :statistics_rounds_path }
        ]
      }
    ].freeze

    def index
      @pages = PAGES
      render layout: 'full'
    end
  end
end
