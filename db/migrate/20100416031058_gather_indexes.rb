class GatherIndexes < ActiveRecord::Migration
  def self.up

    # These indexes were found by searching for AR::Base finds on your applicaton
    # It is strongly recommanded that you will consult a professional DBA about your infrastucture and implemntation before
    # changing your database in that matter.
    # There is a possibility that some of the indexes offered below is not requ red and can be removed and not added, if you require
    # further assistance with your rails application, database infrastructure oany other problem, visit:
    #
    # http://www.railsmentors.org
    # http://www.railstutor.org
    # http://guides.rubyonrails.org


    add_index :brackets, :contest_id
    add_index :contesters, :contest_id
    add_index :contesters, :team_id
    add_index :directories, :parent_id
    add_index :gatherers, :user_id
    add_index :teams, :founder_id
    add_index :bracketers, :match_id
    #add_index :bracketers, :contest_id
    add_index :bracketers, :team_id
    add_index :matches, :server_id
    add_index :matches, :contester1_id
    add_index :matches, :contester2_id
    add_index :matches, :referee_id
    #add_index :matches, :stream_id
    add_index :matches, :map1_id
    add_index :matches, :contest_id
    add_index :matches, :motm_id
    add_index :matches, :map2_id
    add_index :matches, :challenge_id
    add_index :matches, :demo_id
    add_index :matches, :week_id
    add_index :matches, :hltv_id
    add_index :messages, [:sender_id, :sender_type]
    add_index :messages, [:recipient_id, :recipient_type]
    add_index :watchers, :movie_id
    add_index :watchers, :user_id
    add_index :comments, :user_id
    add_index :contests, :rules_id
    add_index :contests, :demos_id
    add_index :contests, :winner_id
    add_index :gathers, :server_id
    add_index :gathers, :captain1_id
    add_index :gathers, :map1_id
    add_index :gathers, :captain2_id
    add_index :gathers, :map2_id
    add_index :groups, :founder_id
    add_index :rounders, :round_id
    add_index :rounders, :team_id
    add_index :rounders, :user_id
    add_index :teamers, :user_id
    add_index :teamers, :team_id
    add_index :votes, [:votable_id, :votable_type]
    add_index :votes, :user_id
    add_index :predictions, :match_id
    add_index :predictions, :user_id
    add_index :shoutmsgs, :user_id
    add_index :topics, :user_id
    add_index :contests_maps, [:map_id, :contest_id]
    add_index :contests_maps, [:contest_id, :map_id]
    add_index :matchers, :match_id
    add_index :matchers, :contester_id
    add_index :matchers, :user_id
    add_index :data_files, :related_id
    add_index :data_files, :directory_id
    add_index :data_files, :article_id
    add_index :articles, :category_id
    add_index :articles, :user_id
    add_index :forums, :category_id
    add_index :groupers, :group_id
    add_index :movies, :match_id
    add_index :movies, :preview_id
    add_index :movies, :user_id
    add_index :bans, :server_id
    add_index :bans, :user_id
    add_index :issues, :assigned_id
    add_index :issues, :category_id
    add_index :issues, :author_id
    add_index :logs, :target_id
    add_index :logs, :server_id
    add_index :logs, :round_id
    add_index :logs, :log_file_id
    #add_index :logs, :details_id
    add_index :logs, :actor_id
    add_index :pcws, :user_id
    add_index :pcws, :team_id
    add_index :posts, :topic_id
    add_index :posts, :user_id
    add_index :users, :team_id
    add_index :admin_requests, :server_id
    add_index :admin_requests, :user_id
    add_index :challenges, :server_id
    add_index :challenges, :contester1_id
    add_index :challenges, :contester2_id
    add_index :challenges, :map1_id
    add_index :challenges, :map2_id
    add_index :challenges, :user_id
    add_index :forumers, :group_id
    add_index :gather_maps, :map_id
    add_index :gather_maps, :gather_id
    add_index :polls, :user_id
    add_index :rounds, :map_id
    add_index :rounds, :team1_id
    add_index :rounds, :server_id
    add_index :rounds, :match_id
    add_index :rounds, :team2_id
    add_index :rounds, :commander_id
    add_index :servers, :match_id
    add_index :servers, :default_id
    add_index :servers, :user_id
    add_index :weeks, :map1_id
    add_index :weeks, :contest_id
    add_index :weeks, :map2_id
    add_index :log_files, :server_id
  end

  def self.down
    remove_index :brackets, :contest_id
    remove_index :contesters, :contest_id
    remove_index :contesters, :team_id
    remove_index :directories, :parent_id
    remove_index :gatherers, :user_id
    remove_index :teams, :founder_id
    remove_index :bracketers, :match_id
    remove_index :bracketers, :contest_id
    remove_index :bracketers, :team_id
    remove_index :matches, :server_id
    remove_index :matches, :contester1_id
    remove_index :matches, :contester2_id
    remove_index :matches, :referee_id
    remove_index :matches, :stream_id
    remove_index :matches, :map1_id
    remove_index :matches, :contest_id
    remove_index :matches, :motm_id
    remove_index :matches, :map2_id
    remove_index :matches, :challenge_id
    remove_index :matches, :demo_id
    remove_index :matches, :week_id
    remove_index :matches, :hltv_id
    remove_index :messages, :column => [:sender_id, :sender_type]
    remove_index :messages, :column => [:recipient_id, :recipient_type]
    remove_index :watchers, :movie_id
    remove_index :watchers, :user_id
    remove_index :comments, :user_id
    remove_index :contests, :rules_id
    remove_index :contests, :demos_id
    remove_index :contests, :winner_id
    remove_index :gathers, :server_id
    remove_index :gathers, :captain1_id
    remove_index :gathers, :map1_id
    remove_index :gathers, :captain2_id
    remove_index :gathers, :map2_id
    remove_index :groups, :founder_id
    remove_index :rounders, :round_id
    remove_index :rounders, :team_id
    remove_index :rounders, :user_id
    remove_index :teamers, :user_id
    remove_index :teamers, :team_id
    remove_index :votes, :column => [:votable_id, :votable_type]
    remove_index :votes, :user_id
    remove_index :predictions, :match_id
    remove_index :predictions, :user_id
    remove_index :shoutmsgs, :user_id
    remove_index :topics, :user_id
    remove_index :contests_maps, :column => [:map_id, :contest_id]
    remove_index :contests_maps, :column => [:contest_id, :map_id]
    remove_index :matchers, :match_id
    remove_index :matchers, :contester_id
    remove_index :matchers, :user_id
    remove_index :data_files, :related_id
    remove_index :data_files, :directory_id
    remove_index :data_files, :article_id
    remove_index :articles, :category_id
    remove_index :articles, :user_id
    remove_index :forums, :category_id
    remove_index :groupers, :group_id
    remove_index :movies, :match_id
    remove_index :movies, :preview_id
    remove_index :movies, :user_id
    remove_index :bans, :server_id
    remove_index :bans, :user_id
    remove_index :issues, :assigned_id
    remove_index :issues, :category_id
    remove_index :issues, :author_id
    remove_index :logs, :target_id
    remove_index :logs, :server_id
    remove_index :logs, :round_id
    remove_index :logs, :log_file_id
    remove_index :logs, :details_id
    remove_index :logs, :actor_id
    remove_index :pcws, :user_id
    remove_index :pcws, :team_id
    remove_index :posts, :topic_id
    remove_index :posts, :user_id
    remove_index :users, :team_id
    remove_index :admin_requests, :server_id
    remove_index :admin_requests, :user_id
    remove_index :challenges, :server_id
    remove_index :challenges, :contester1_id
    remove_index :challenges, :contester2_id
    remove_index :challenges, :map1_id
    remove_index :challenges, :map2_id
    remove_index :challenges, :user_id
    remove_index :forumers, :group_id
    remove_index :gather_maps, :map_id
    remove_index :gather_maps, :gather_id
    remove_index :polls, :user_id
    remove_index :rounds, :map_id
    remove_index :rounds, :team1_id
    remove_index :rounds, :server_id
    remove_index :rounds, :match_id
    remove_index :rounds, :team2_id
    remove_index :rounds, :commander_id
    remove_index :servers, :match_id
    remove_index :servers, :default_id
    remove_index :servers, :user_id
    remove_index :weeks, :map1_id
    remove_index :weeks, :contest_id
    remove_index :weeks, :map2_id
    remove_index :log_files, :server_id
  end
end