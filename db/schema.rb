# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140510080652) do

  create_table "article_versions", :force => true do |t|
    t.integer  "article_id"
    t.integer  "version"
    t.string   "title"
    t.text     "text",        :limit => 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "text_parsed", :limit => 16777215
    t.integer  "text_coding",                     :default => 0, :null => false
  end

  add_index "article_versions", ["article_id"], :name => "index_article_versions_on_article_id"

  create_table "articles", :force => true do |t|
    t.string   "title"
    t.integer  "status",                                         :null => false
    t.integer  "category_id"
    t.text     "text",        :limit => 16777215
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "version"
    t.text     "text_parsed", :limit => 16777215
    t.integer  "text_coding",                     :default => 0, :null => false
  end

  add_index "articles", ["category_id"], :name => "index_articles_on_category_id"
  add_index "articles", ["created_at", "status"], :name => "index_articles_on_created_at_and_status"
  add_index "articles", ["created_at"], :name => "index_articles_on_created_at"
  add_index "articles", ["user_id"], :name => "index_articles_on_user_id"

  create_table "bans", :force => true do |t|
    t.string   "steamid"
    t.integer  "user_id"
    t.string   "addr"
    t.integer  "server_id"
    t.datetime "expiry"
    t.string   "reason"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "ban_type"
    t.string   "ip"
  end

  add_index "bans", ["server_id"], :name => "index_bans_on_server_id"
  add_index "bans", ["user_id"], :name => "index_bans_on_user_id"

  create_table "bracketers", :force => true do |t|
    t.integer  "bracket_id"
    t.integer  "column"
    t.integer  "row"
    t.integer  "match_id"
    t.integer  "team_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "bracketers", ["match_id"], :name => "index_bracketers_on_match_id"
  add_index "bracketers", ["team_id"], :name => "index_bracketers_on_team_id"

  create_table "brackets", :force => true do |t|
    t.integer  "contest_id"
    t.integer  "slots"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
  end

  add_index "brackets", ["contest_id"], :name => "index_brackets_on_contest_id"

  create_table "categories", :force => true do |t|
    t.string   "name"
    t.integer  "sort"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "domain"
  end

  add_index "categories", ["domain"], :name => "index_categories_on_domain"
  add_index "categories", ["sort"], :name => "index_categories_on_sort"

  create_table "challenges", :force => true do |t|
    t.integer  "contester1_id"
    t.integer  "contester2_id"
    t.datetime "match_time"
    t.datetime "default_time"
    t.boolean  "mandatory"
    t.integer  "server_id"
    t.integer  "user_id"
    t.string   "details"
    t.string   "response"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "map1_id"
    t.string   "map2_id"
    t.integer  "status",        :default => 0, :null => false
  end

  add_index "challenges", ["contester1_id"], :name => "index_challenges_on_contester1_id"
  add_index "challenges", ["contester2_id"], :name => "index_challenges_on_contester2_id"
  add_index "challenges", ["map1_id"], :name => "index_challenges_on_map1_id"
  add_index "challenges", ["map2_id"], :name => "index_challenges_on_map2_id"
  add_index "challenges", ["server_id"], :name => "index_challenges_on_server_id"
  add_index "challenges", ["user_id"], :name => "index_challenges_on_user_id"

  create_table "comments", :force => true do |t|
    t.text     "text"
    t.integer  "user_id"
    t.string   "commentable_type"
    t.integer  "commentable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "text_parsed"
  end

  add_index "comments", ["commentable_type", "commentable_id"], :name => "index_comments_on_commentable_type_and_commentable_id"
  add_index "comments", ["commentable_type", "id"], :name => "index_comments_on_commentable_type_and_id"
  add_index "comments", ["commentable_type"], :name => "index_comments_on_commentable_type"
  add_index "comments", ["user_id"], :name => "index_comments_on_user_id"

  create_table "contesters", :force => true do |t|
    t.integer  "team_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "score",      :default => 0,    :null => false
    t.integer  "win",        :default => 0,    :null => false
    t.integer  "loss",       :default => 0,    :null => false
    t.integer  "draw",       :default => 0,    :null => false
    t.integer  "contest_id"
    t.integer  "trend",                        :null => false
    t.integer  "extra",                        :null => false
    t.boolean  "active",     :default => true, :null => false
  end

  add_index "contesters", ["contest_id"], :name => "index_contesters_on_contest_id"
  add_index "contesters", ["team_id"], :name => "index_contesters_on_team_id"

  create_table "contests", :force => true do |t|
    t.string   "name"
    t.datetime "start"
    t.datetime "end"
    t.integer  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.time     "default_time"
    t.integer  "contest_type", :default => 0, :null => false
    t.integer  "winner_id"
    t.integer  "demos_id"
    t.string   "short_name"
    t.integer  "weight"
    t.integer  "modulus_base"
    t.float    "modulus_even"
    t.float    "modulus_3to1"
    t.float    "modulus_4to0"
    t.integer  "rules_id"
  end

  add_index "contests", ["demos_id"], :name => "index_contests_on_demos_id"
  add_index "contests", ["rules_id"], :name => "index_contests_on_rules_id"
  add_index "contests", ["status"], :name => "index_contests_on_status"
  add_index "contests", ["winner_id"], :name => "index_contests_on_winner_id"

  create_table "contests_maps", :id => false, :force => true do |t|
    t.integer "contest_id"
    t.integer "map_id"
  end

  add_index "contests_maps", ["contest_id", "map_id"], :name => "index_contests_maps_on_contest_id_and_map_id"
  add_index "contests_maps", ["map_id", "contest_id"], :name => "index_contests_maps_on_map_id_and_contest_id"

  create_table "data_files", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.string   "path"
    t.integer  "size",         :null => false
    t.string   "md5"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "directory_id"
    t.integer  "related_id"
    t.integer  "article_id"
  end

  add_index "data_files", ["article_id"], :name => "index_data_files_on_article_id"
  add_index "data_files", ["directory_id"], :name => "index_data_files_on_directory_id"
  add_index "data_files", ["related_id"], :name => "index_data_files_on_related_id"

  create_table "directories", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.string   "path"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "parent_id"
    t.boolean  "hidden",      :default => false, :null => false
  end

  add_index "directories", ["parent_id"], :name => "index_directories_on_parent_id"

  create_table "forumers", :force => true do |t|
    t.integer  "forum_id"
    t.integer  "group_id"
    t.integer  "access"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "forums", :force => true do |t|
    t.string   "title"
    t.string   "description"
    t.integer  "category_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  add_index "forums", ["category_id"], :name => "index_forums_on_category_id"

  create_table "gather_maps", :force => true do |t|
    t.integer "gather_id"
    t.integer "map_id"
    t.integer "votes"
  end

  add_index "gather_maps", ["gather_id"], :name => "index_gather_maps_on_gather_id"
  add_index "gather_maps", ["map_id"], :name => "index_gather_maps_on_map_id"

  create_table "gather_servers", :force => true do |t|
    t.integer  "gather_id"
    t.integer  "server_id"
    t.integer  "votes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "gatherers", :force => true do |t|
    t.integer  "user_id"
    t.integer  "gather_id"
    t.integer  "team"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "votes",      :default => 0, :null => false
  end

  add_index "gatherers", ["gather_id"], :name => "index_gatherers_on_gather_id"
  add_index "gatherers", ["updated_at", "gather_id"], :name => "index_gatherers_on_updated_at_and_gather_id"
  add_index "gatherers", ["user_id"], :name => "index_gatherers_on_user_id"

  create_table "gathers", :force => true do |t|
    t.integer  "status"
    t.integer  "captain1_id"
    t.integer  "captain2_id"
    t.integer  "map1_id"
    t.integer  "map2_id"
    t.integer  "server_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "turn"
    t.datetime "lastpick1"
    t.datetime "lastpick2"
    t.integer  "votes",       :default => 0, :null => false
    t.integer  "category_id"
  end

  add_index "gathers", ["captain1_id"], :name => "index_gathers_on_captain1_id"
  add_index "gathers", ["captain2_id"], :name => "index_gathers_on_captain2_id"
  add_index "gathers", ["map1_id"], :name => "index_gathers_on_map1_id"
  add_index "gathers", ["map2_id"], :name => "index_gathers_on_map2_id"
  add_index "gathers", ["server_id"], :name => "index_gathers_on_server_id"

  create_table "gathers_users", :id => false, :force => true do |t|
    t.integer "gather_id", :null => false
    t.integer "user_id",   :null => false
  end

  create_table "groupers", :force => true do |t|
    t.integer  "group_id"
    t.integer  "user_id"
    t.string   "task"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "groupers", ["group_id"], :name => "index_groupers_on_group_id"
  add_index "groupers", ["user_id"], :name => "index_groupers_on_user_id"

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "founder_id"
  end

  add_index "groups", ["founder_id"], :name => "index_groups_on_founder_id"

  create_table "groups_users", :id => false, :force => true do |t|
    t.integer "group_id", :null => false
    t.integer "user_id",  :null => false
  end

  create_table "issues", :force => true do |t|
    t.string   "title"
    t.integer  "status"
    t.integer  "assigned_id"
    t.integer  "category_id"
    t.text     "text"
    t.integer  "author_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "solution"
    t.text     "text_parsed"
  end

  add_index "issues", ["assigned_id"], :name => "index_issues_on_assigned_id"
  add_index "issues", ["author_id"], :name => "index_issues_on_author_id"
  add_index "issues", ["category_id"], :name => "index_issues_on_category_id"

  create_table "locks", :force => true do |t|
    t.integer  "lockable_id"
    t.string   "lockable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "locks", ["lockable_id", "lockable_type"], :name => "index_locks_on_lockable_id_and_lockable_type"

  create_table "log_events", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.integer  "team"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "log_files", :force => true do |t|
    t.string   "name"
    t.string   "md5"
    t.integer  "size"
    t.integer  "server_id"
    t.datetime "updated_at"
  end

  add_index "log_files", ["server_id"], :name => "index_log_files_on_server_id"

  create_table "logs", :force => true do |t|
    t.integer  "server_id"
    t.text     "text"
    t.integer  "domain"
    t.datetime "created_at"
    t.integer  "round_id"
    t.string   "details"
    t.integer  "actor_id"
    t.integer  "target_id"
    t.string   "specifics1"
    t.string   "specifics2"
    t.integer  "log_file_id"
  end

  add_index "logs", ["actor_id"], :name => "index_logs_on_actor_id"
  add_index "logs", ["log_file_id"], :name => "index_logs_on_log_file_id"
  add_index "logs", ["round_id"], :name => "index_logs_on_round_id"
  add_index "logs", ["server_id"], :name => "index_logs_on_server_id"
  add_index "logs", ["target_id"], :name => "index_logs_on_target_id"

  create_table "maps", :force => true do |t|
    t.string   "name"
    t.string   "download"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "deleted",     :default => false, :null => false
    t.string   "picture"
    t.integer  "category_id"
  end

  create_table "matchers", :force => true do |t|
    t.integer  "match_id",     :null => false
    t.integer  "user_id",      :null => false
    t.integer  "contester_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "merc",         :null => false
  end

  add_index "matchers", ["contester_id"], :name => "index_matchers_on_contester_id"
  add_index "matchers", ["match_id"], :name => "index_matchers_on_match_id"
  add_index "matchers", ["user_id"], :name => "index_matchers_on_user_id"

  create_table "matches", :force => true do |t|
    t.integer  "contester1_id"
    t.integer  "contester2_id"
    t.integer  "score1"
    t.integer  "score2"
    t.datetime "match_time"
    t.integer  "challenge_id"
    t.integer  "contest_id"
    t.text     "report"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "map1_id"
    t.integer  "map2_id"
    t.integer  "server_id"
    t.integer  "motm_id"
    t.integer  "demo_id"
    t.integer  "week_id"
    t.integer  "referee_id"
    t.boolean  "forfeit"
    t.integer  "diff"
    t.integer  "points1"
    t.integer  "points2"
    t.integer  "hltv_id"
    t.string   "caster_id"
  end

  add_index "matches", ["challenge_id"], :name => "index_matches_on_challenge_id"
  add_index "matches", ["contest_id"], :name => "index_matches_on_contest_id"
  add_index "matches", ["contester1_id"], :name => "index_matches_on_contester1_id"
  add_index "matches", ["contester2_id"], :name => "index_matches_on_contester2_id"
  add_index "matches", ["demo_id"], :name => "index_matches_on_demo_id"
  add_index "matches", ["hltv_id"], :name => "index_matches_on_hltv_id"
  add_index "matches", ["map1_id"], :name => "index_matches_on_map1_id"
  add_index "matches", ["map2_id"], :name => "index_matches_on_map2_id"
  add_index "matches", ["match_time"], :name => "index_matches_on_match_time"
  add_index "matches", ["motm_id"], :name => "index_matches_on_motm_id"
  add_index "matches", ["referee_id"], :name => "index_matches_on_referee_id"
  add_index "matches", ["score1", "score2"], :name => "index_matches_on_score1_and_score2"
  add_index "matches", ["server_id"], :name => "index_matches_on_server_id"
  add_index "matches", ["week_id"], :name => "index_matches_on_week_id"

  create_table "messages", :force => true do |t|
    t.string   "sender_type"
    t.integer  "sender_id"
    t.string   "recipient_type"
    t.integer  "recipient_id"
    t.string   "title"
    t.text     "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "text_parsed"
  end

  add_index "messages", ["recipient_id", "recipient_type"], :name => "index_messages_on_recipient_id_and_recipient_type"
  add_index "messages", ["sender_id", "sender_type"], :name => "index_messages_on_sender_id_and_sender_type"

  create_table "movies", :force => true do |t|
    t.string   "name"
    t.string   "content"
    t.string   "format"
    t.integer  "user_id"
    t.integer  "file_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "picture"
    t.integer  "preview_id"
    t.integer  "length"
    t.integer  "match_id"
    t.integer  "status"
    t.integer  "category_id"
  end

  add_index "movies", ["file_id"], :name => "index_movies_on_file_id"
  add_index "movies", ["match_id"], :name => "index_movies_on_match_id"
  add_index "movies", ["preview_id"], :name => "index_movies_on_preview_id"
  add_index "movies", ["status"], :name => "index_movies_on_status"
  add_index "movies", ["user_id"], :name => "index_movies_on_user_id"

  create_table "options", :force => true do |t|
    t.string   "option"
    t.integer  "poll_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "votes",      :default => 0, :null => false
  end

  add_index "options", ["poll_id"], :name => "index_options_on_poll_id"

  create_table "pcws", :force => true do |t|
    t.integer  "team_id"
    t.integer  "user_id"
    t.datetime "match_time"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "pcws", ["match_time"], :name => "index_pcws_on_match_time"
  add_index "pcws", ["team_id"], :name => "index_pcws_on_team_id"
  add_index "pcws", ["user_id"], :name => "index_pcws_on_user_id"

  create_table "polls", :force => true do |t|
    t.string   "question"
    t.datetime "end_date"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "votes",      :default => 0, :null => false
  end

  add_index "polls", ["user_id"], :name => "index_polls_on_user_id"

  create_table "posts", :force => true do |t|
    t.text     "text"
    t.integer  "topic_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "text_parsed"
  end

  add_index "posts", ["topic_id"], :name => "index_posts_on_topic_id"
  add_index "posts", ["user_id"], :name => "index_posts_on_user_id"

  create_table "predictions", :force => true do |t|
    t.integer  "match_id"
    t.integer  "user_id"
    t.integer  "score1"
    t.integer  "score2"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "result"
  end

  add_index "predictions", ["match_id"], :name => "index_predictions_on_match_id"
  add_index "predictions", ["user_id"], :name => "index_predictions_on_user_id"

  create_table "profiles", :force => true do |t|
    t.integer  "user_id"
    t.string   "msn"
    t.string   "icq"
    t.string   "irc"
    t.string   "web"
    t.string   "town"
    t.string   "singleplayer"
    t.string   "multiplayer"
    t.string   "food"
    t.string   "beverage"
    t.string   "hobby"
    t.string   "music"
    t.string   "book"
    t.string   "movie"
    t.string   "tvseries"
    t.string   "res"
    t.string   "sensitivity"
    t.string   "monitor_hz"
    t.string   "scripts"
    t.string   "cpu"
    t.string   "gpu"
    t.string   "ram"
    t.string   "psu"
    t.string   "motherboard"
    t.string   "soundcard"
    t.string   "hdd"
    t.string   "case"
    t.string   "monitor"
    t.string   "mouse"
    t.string   "mouse_pad"
    t.string   "keyboard"
    t.string   "head_phones"
    t.string   "speakers"
    t.text     "achievements"
    t.datetime "updated_at"
    t.string   "signature"
    t.string   "avatar"
    t.string   "clan_search"
    t.boolean  "notify_news"
    t.boolean  "notify_articles"
    t.boolean  "notify_movies"
    t.boolean  "notify_gather"
    t.boolean  "notify_own_match"
    t.boolean  "notify_any_match"
    t.boolean  "notify_pms",          :default => true, :null => false
    t.boolean  "notify_challenge",    :default => true, :null => false
    t.string   "steam_profile"
    t.string   "achievements_parsed"
    t.string   "signature_parsed"
    t.string   "stream"
  end

  add_index "profiles", ["user_id"], :name => "index_profiles_on_user_id"

  create_table "rates", :force => true do |t|
    t.integer "score"
  end

  create_table "ratings", :force => true do |t|
    t.integer  "user_id"
    t.integer  "rate_id"
    t.integer  "rateable_id"
    t.string   "rateable_type", :limit => 32
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "ratings", ["rate_id"], :name => "index_ratings_on_rate_id"
  add_index "ratings", ["rateable_id", "rateable_type"], :name => "index_ratings_on_rateable_id_and_rateable_type"

  create_table "readings", :force => true do |t|
    t.string   "readable_type"
    t.integer  "readable_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "readings", ["readable_type", "readable_id"], :name => "index_readings_on_readable_type_and_readable_id"
  add_index "readings", ["user_id", "readable_id", "readable_type"], :name => "index_readings_on_user_id_and_readable_id_and_readable_type"
  add_index "readings", ["user_id"], :name => "index_readings_on_user_id"

  create_table "rounders", :force => true do |t|
    t.integer "round_id"
    t.integer "user_id"
    t.integer "team"
    t.string  "roles"
    t.integer "kills"
    t.integer "deaths"
    t.string  "name"
    t.string  "steamid"
    t.integer "team_id"
  end

  add_index "rounders", ["round_id"], :name => "index_rounders_on_round_id"
  add_index "rounders", ["team_id"], :name => "index_rounders_on_team_id"
  add_index "rounders", ["user_id"], :name => "index_rounders_on_user_id"

  create_table "rounds", :force => true do |t|
    t.integer  "server_id"
    t.datetime "start"
    t.datetime "end"
    t.integer  "winner"
    t.integer  "match_id"
    t.integer  "commander_id"
    t.integer  "team1_id"
    t.integer  "team2_id"
    t.string   "map_name"
    t.integer  "map_id"
  end

  add_index "rounds", ["commander_id"], :name => "index_rounds_on_commander_id"
  add_index "rounds", ["map_id"], :name => "index_rounds_on_map_id"
  add_index "rounds", ["match_id"], :name => "index_rounds_on_match_id"
  add_index "rounds", ["server_id"], :name => "index_rounds_on_server_id"
  add_index "rounds", ["team1_id"], :name => "index_rounds_on_team1_id"
  add_index "rounds", ["team2_id"], :name => "index_rounds_on_team2_id"

  create_table "server_versions", :force => true do |t|
    t.integer  "server_id"
    t.integer  "version"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "map"
    t.integer  "players"
    t.integer  "max_players"
    t.string   "ping"
  end

  add_index "server_versions", ["server_id"], :name => "index_server_versions_on_server_id"

  create_table "servers", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.string   "dns"
    t.string   "ip"
    t.string   "port"
    t.string   "rcon"
    t.string   "password"
    t.string   "irc"
    t.integer  "user_id"
    t.boolean  "official"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "map"
    t.integer  "players"
    t.integer  "max_players"
    t.string   "ping"
    t.integer  "version"
    t.integer  "domain",          :default => 0,    :null => false
    t.string   "reservation"
    t.string   "recording"
    t.datetime "idle"
    t.integer  "default_id"
    t.boolean  "active",          :default => true, :null => false
    t.string   "recordable_type"
    t.integer  "recordable_id"
    t.integer  "category_id"
  end

  add_index "servers", ["default_id"], :name => "index_servers_on_default_id"
  add_index "servers", ["players", "domain"], :name => "index_servers_on_players_and_domain"
  add_index "servers", ["user_id"], :name => "index_servers_on_user_id"

  create_table "sessions", :force => true do |t|
    t.string   "session_id",                       :null => false
    t.text     "data",       :limit => 2147483647
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "shoutmsg_archive", :force => true do |t|
    t.integer  "user_id"
    t.string   "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "shoutable_type"
    t.integer  "shoutable_id"
  end

  add_index "shoutmsg_archive", ["shoutable_type", "shoutable_id"], :name => "index_shoutmsgs_on_shoutable_type_and_shoutable_id"
  add_index "shoutmsg_archive", ["user_id"], :name => "index_shoutmsgs_on_user_id"

  create_table "shoutmsgs", :force => true do |t|
    t.integer  "user_id"
    t.string   "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "shoutable_type"
    t.integer  "shoutable_id"
  end

  add_index "shoutmsgs", ["shoutable_type", "shoutable_id"], :name => "index_shoutmsgs_on_shoutable_type_and_shoutable_id"
  add_index "shoutmsgs", ["user_id"], :name => "index_shoutmsgs_on_user_id"

  create_table "sites", :force => true do |t|
    t.string   "name"
    t.string   "url"
    t.integer  "category_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "favicon"
  end

  add_index "sites", ["category_id"], :name => "index_sites_on_category_id"
  add_index "sites", ["created_at"], :name => "index_sites_on_created_at"

  create_table "teamers", :force => true do |t|
    t.integer  "team_id",    :null => false
    t.integer  "user_id",    :null => false
    t.string   "comment"
    t.integer  "rank",       :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "teamers", ["team_id"], :name => "index_teamers_on_team_id"
  add_index "teamers", ["user_id"], :name => "index_teamers_on_user_id"

  create_table "teams", :force => true do |t|
    t.string   "name"
    t.string   "irc"
    t.string   "web"
    t.string   "tag"
    t.string   "country"
    t.string   "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "logo"
    t.integer  "founder_id"
    t.boolean  "active",     :default => true, :null => false
    t.string   "recruiting"
  end

  add_index "teams", ["founder_id"], :name => "index_teams_on_founder_id"

  create_table "topics", :force => true do |t|
    t.string   "title"
    t.integer  "user_id"
    t.integer  "forum_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "state",      :default => 0, :null => false
  end

  add_index "topics", ["forum_id"], :name => "index_topics_on_forum_id"
  add_index "topics", ["user_id"], :name => "index_topics_on_user_id"

  create_table "tweets", :force => true do |t|
    t.string   "msg"
    t.string   "link"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tweets", ["created_at"], :name => "index_tweets_on_created_at"

  create_table "user_versions", :force => true do |t|
    t.integer  "user_id"
    t.integer  "version"
    t.string   "steamid"
    t.string   "username"
    t.string   "lastip"
    t.datetime "updated_at"
  end

  add_index "user_versions", ["steamid"], :name => "index_user_versions_on_steamid"
  add_index "user_versions", ["user_id"], :name => "index_user_versions_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "username"
    t.string   "password"
    t.string   "firstname"
    t.string   "lastname"
    t.string   "email"
    t.string   "steamid"
    t.integer  "team_id"
    t.datetime "lastvisit"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "lastip"
    t.string   "country"
    t.date     "birthdate"
    t.string   "time_zone"
    t.integer  "version"
    t.boolean  "public_email", :default => false, :null => false
  end

  add_index "users", ["team_id"], :name => "index_users_on_team_id"

  create_table "versions", :force => true do |t|
    t.string   "item_type",  :null => false
    t.integer  "item_id",    :null => false
    t.string   "event",      :null => false
    t.string   "whodunnit"
    t.text     "object"
    t.datetime "created_at"
  end

  add_index "versions", ["item_type", "item_id"], :name => "index_versions_on_item_type_and_item_id"

  create_table "view_counts", :force => true do |t|
    t.integer "viewable_id"
    t.string  "viewable_type"
    t.string  "ip_address"
    t.boolean "logged_in"
    t.date    "created_at"
  end

  add_index "view_counts", ["viewable_type", "viewable_id"], :name => "index_view_counts_on_viewable_type_and_viewable_id"

  create_table "votes", :force => true do |t|
    t.integer "user_id"
    t.integer "votable_id"
    t.integer "poll_id"
    t.string  "votable_type"
  end

  add_index "votes", ["user_id"], :name => "index_votes_on_user_id"
  add_index "votes", ["votable_id", "votable_type"], :name => "index_votes_on_votable_id_and_votable_type"

  create_table "watchers", :force => true do |t|
    t.integer  "user_id"
    t.integer  "movie_id"
    t.boolean  "banned",     :default => false, :null => false
    t.datetime "updated_at"
  end

  add_index "watchers", ["movie_id"], :name => "index_watchers_on_movie_id"
  add_index "watchers", ["user_id"], :name => "index_watchers_on_user_id"

  create_table "weeks", :force => true do |t|
    t.string   "name"
    t.date     "start_date"
    t.integer  "contest_id"
    t.integer  "map1_id"
    t.integer  "map2_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "weeks", ["contest_id"], :name => "index_weeks_on_contest_id"
  add_index "weeks", ["map1_id"], :name => "index_weeks_on_map1_id"
  add_index "weeks", ["map2_id"], :name => "index_weeks_on_map2_id"

end
