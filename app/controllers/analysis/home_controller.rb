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
        title: 'Rankings',
        description: 'Skill ratings and win/loss records for every tracked player. Sort by any column.',
        icon: 'trophy',
        path_helper: :analysis_users_path
      },
      {
        title: 'Team rankings',
        description: 'OpenSkill ratings, records and tournament wins for every team, NS1 and NS2 separately.',
        icon: 'users',
        path_helper: :analysis_teams_path
      },
      {
        title: 'Map balance',
        description: 'Marine vs alien win rates for every map currently in rotation.',
        icon: 'map',
        path_helper: :analysis_maps_path
      },
      {
        title: 'NS1 pick order',
        description: 'How fast NS1 players usually get picked when gather teams are drafted.',
        icon: 'sort-numeric-down',
        path_helper: :analysis_pick_orders_path
      }
    ].freeze

    def index
      @pages = PAGES
      render layout: 'full'
    end
  end
end
