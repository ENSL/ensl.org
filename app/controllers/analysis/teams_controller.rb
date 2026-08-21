# frozen_string_literal: true

module Analysis
  # /analysis/teams -- one row per team that has played at least one finished
  # match, with its win/loss/draw record, tournament victories and an
  # OpenSkill rating replayed from the site's own match history. NS1 and NS2
  # are ranked separately (see Contest.for_game); sorting is client-side, so
  # the only params are the game and the minimum-matches cutoff.
  class TeamsController < Analysis::BaseController
    # The page's own default cutoff, higher than TeamRankingQuery's library
    # default of 1, so freshly loaded rankings aren't dominated by teams that
    # have barely played.
    DEFAULT_MIN_MATCHES = 5

    def index
      @games = Contest::GAMES
      @selected_game = TeamRankingQuery.normalize_game(params[:game])
      @min_matches_options = TeamRankingQuery::MIN_MATCHES_OPTIONS
      @selected_min_matches = TeamRankingQuery.normalize_min_matches(params[:min_matches] || DEFAULT_MIN_MATCHES)
      @rankings = TeamRankingQuery.call(game: @selected_game, min_matches: @selected_min_matches)
      render layout: 'full_wide'
    end
  end
end
