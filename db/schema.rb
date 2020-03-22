# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_03_15_183444) do

  create_table "article_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "article_id"
    t.integer "version"
    t.string "title"
    t.text "text", size: :medium
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "text_parsed", size: :medium
    t.integer "text_coding", default: 0, null: false
    t.index ["article_id"], name: "index_article_versions_on_article_id"
  end

  create_table "articles", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "title"
    t.integer "status", null: false
    t.integer "category_id"
    t.text "text", size: :medium
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "version"
    t.text "text_parsed", size: :medium
    t.integer "text_coding", default: 0, null: false
    t.index ["category_id"], name: "index_articles_on_category_id"
    t.index ["created_at", "status"], name: "index_articles_on_created_at_and_status"
    t.index ["created_at"], name: "index_articles_on_created_at"
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "bans", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "steamid"
    t.integer "user_id"
    t.string "addr"
    t.integer "server_id"
    t.datetime "expiry"
    t.string "reason"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "ban_type"
    t.string "ip"
    t.integer "creator_id"
    t.index ["creator_id"], name: "index_bans_on_creator_id"
    t.index ["server_id"], name: "index_bans_on_server_id"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "bracketers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "bracket_id"
    t.integer "column"
    t.integer "row"
    t.integer "match_id"
    t.integer "team_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["match_id"], name: "index_bracketers_on_match_id"
    t.index ["team_id"], name: "index_bracketers_on_team_id"
  end

  create_table "brackets", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "contest_id"
    t.integer "slots"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.index ["contest_id"], name: "index_brackets_on_contest_id"
  end

  create_table "categories", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.integer "sort"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "domain"
    t.index ["domain"], name: "index_categories_on_domain"
    t.index ["sort"], name: "index_categories_on_sort"
  end

  create_table "challenges", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "contester1_id"
    t.integer "contester2_id"
    t.datetime "match_time"
    t.datetime "default_time"
    t.boolean "mandatory"
    t.integer "server_id"
    t.integer "user_id"
    t.string "details"
    t.string "response"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "map1_id"
    t.string "map2_id"
    t.integer "status", default: 0, null: false
    t.index ["contester1_id"], name: "index_challenges_on_contester1_id"
    t.index ["contester2_id"], name: "index_challenges_on_contester2_id"
    t.index ["map1_id"], name: "index_challenges_on_map1_id"
    t.index ["map2_id"], name: "index_challenges_on_map2_id"
    t.index ["server_id"], name: "index_challenges_on_server_id"
    t.index ["user_id"], name: "index_challenges_on_user_id"
  end

  create_table "comments", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "text"
    t.integer "user_id"
    t.string "commentable_type"
    t.integer "commentable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "text_parsed"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["commentable_type", "id"], name: "index_comments_on_commentable_type_and_id"
    t.index ["commentable_type"], name: "index_comments_on_commentable_type"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "contesters", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "team_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "score", default: 0, null: false
    t.integer "win", default: 0, null: false
    t.integer "loss", default: 0, null: false
    t.integer "draw", default: 0, null: false
    t.integer "contest_id"
    t.integer "trend", null: false
    t.integer "extra", null: false
    t.boolean "active", default: true, null: false
    t.index ["contest_id"], name: "index_contesters_on_contest_id"
    t.index ["team_id"], name: "index_contesters_on_team_id"
  end

  create_table "contests", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.datetime "start"
    t.datetime "end"
    t.integer "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.time "default_time"
    t.integer "contest_type", default: 0, null: false
    t.integer "winner_id"
    t.integer "demos_id"
    t.string "short_name"
    t.integer "weight"
    t.integer "modulus_base"
    t.float "modulus_even"
    t.float "modulus_3to1"
    t.float "modulus_4to0"
    t.integer "rules_id"
    t.index ["demos_id"], name: "index_contests_on_demos_id"
    t.index ["rules_id"], name: "index_contests_on_rules_id"
    t.index ["status"], name: "index_contests_on_status"
    t.index ["winner_id"], name: "index_contests_on_winner_id"
  end

  create_table "contests_maps", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "contest_id"
    t.integer "map_id"
    t.index ["contest_id", "map_id"], name: "index_contests_maps_on_contest_id_and_map_id"
    t.index ["map_id", "contest_id"], name: "index_contests_maps_on_map_id_and_contest_id"
  end

  create_table "custom_urls", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name"
    t.integer "article_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_custom_urls_on_article_id"
    t.index ["name"], name: "index_custom_urls_on_name"
  end

  create_table "data_files", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "path"
    t.integer "size", null: false
    t.string "md5"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "directory_id"
    t.integer "related_id"
    t.integer "article_id"
    t.index ["article_id"], name: "index_data_files_on_article_id"
    t.index ["directory_id"], name: "index_data_files_on_directory_id"
    t.index ["related_id"], name: "index_data_files_on_related_id"
  end

  create_table "directories", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "path"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "parent_id"
    t.boolean "hidden", default: false, null: false
    t.index ["parent_id"], name: "index_directories_on_parent_id"
  end

  create_table "forumers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "forum_id"
    t.integer "group_id"
    t.integer "access"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["forum_id"], name: "index_forumers_on_forum_id"
    t.index ["group_id"], name: "index_forumers_on_group_id"
  end

  create_table "forums", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.integer "category_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "position"
    t.index ["category_id"], name: "index_forums_on_category_id"
  end

  create_table "gather_maps", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "gather_id"
    t.integer "map_id"
    t.integer "votes"
    t.index ["gather_id"], name: "index_gather_maps_on_gather_id"
    t.index ["map_id"], name: "index_gather_maps_on_map_id"
  end

  create_table "gather_servers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "gather_id"
    t.integer "server_id"
    t.integer "votes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "gatherers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "gather_id"
    t.integer "team"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "votes", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.index ["gather_id"], name: "index_gatherers_on_gather_id"
    t.index ["updated_at", "gather_id"], name: "index_gatherers_on_updated_at_and_gather_id"
    t.index ["user_id"], name: "index_gatherers_on_user_id"
  end

  create_table "gathers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "status"
    t.integer "captain1_id"
    t.integer "captain2_id"
    t.integer "map1_id"
    t.integer "map2_id"
    t.integer "server_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "turn"
    t.datetime "lastpick1"
    t.datetime "lastpick2"
    t.integer "votes", default: 0, null: false
    t.integer "category_id"
    t.index ["captain1_id"], name: "index_gathers_on_captain1_id"
    t.index ["captain2_id"], name: "index_gathers_on_captain2_id"
    t.index ["map1_id"], name: "index_gathers_on_map1_id"
    t.index ["map2_id"], name: "index_gathers_on_map2_id"
    t.index ["server_id"], name: "index_gathers_on_server_id"
  end

  create_table "gathers_users", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "gather_id", null: false
    t.integer "user_id", null: false
  end

  create_table "groupers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.string "task"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_id"], name: "index_groupers_on_group_id"
    t.index ["user_id"], name: "index_groupers_on_user_id"
  end

  create_table "groups", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "founder_id"
    t.index ["founder_id"], name: "index_groups_on_founder_id"
  end

  create_table "groups_users", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id", null: false
  end

  create_table "issues", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "title"
    t.integer "status"
    t.integer "assigned_id"
    t.integer "category_id"
    t.text "text"
    t.integer "author_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "solution"
    t.text "text_parsed"
    t.index ["assigned_id"], name: "index_issues_on_assigned_id"
    t.index ["author_id"], name: "index_issues_on_author_id"
    t.index ["category_id"], name: "index_issues_on_category_id"
  end

  create_table "locks", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "lockable_id"
    t.string "lockable_type", collation: "utf8_general_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["lockable_id", "lockable_type"], name: "index_locks_on_lockable_id_and_lockable_type"
  end

  create_table "log_events", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.integer "team"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "log_files", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.string "name"
    t.string "md5"
    t.integer "size"
    t.integer "server_id"
    t.datetime "updated_at"
    t.index ["server_id"], name: "index_log_files_on_server_id"
  end

  create_table "logs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "server_id"
    t.text "text"
    t.integer "domain"
    t.datetime "created_at"
    t.integer "round_id"
    t.string "details"
    t.integer "actor_id"
    t.integer "target_id"
    t.string "specifics1"
    t.string "specifics2"
    t.integer "log_file_id"
    t.index ["actor_id"], name: "index_logs_on_actor_id"
    t.index ["log_file_id"], name: "index_logs_on_log_file_id"
    t.index ["round_id"], name: "index_logs_on_round_id"
    t.index ["server_id"], name: "index_logs_on_server_id"
    t.index ["target_id"], name: "index_logs_on_target_id"
  end

  create_table "maps", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.string "download"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "deleted", default: false, null: false
    t.string "picture"
    t.integer "category_id"
  end

  create_table "match_proposals", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "match_id"
    t.integer "team_id"
    t.datetime "proposed_time"
    t.integer "status"
    t.index ["status"], name: "index_match_proposals_on_status"
  end

  create_table "matchers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "match_id", null: false
    t.integer "user_id", null: false
    t.integer "contester_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "merc", null: false
    t.index ["contester_id"], name: "index_matchers_on_contester_id"
    t.index ["match_id"], name: "index_matchers_on_match_id"
    t.index ["user_id"], name: "index_matchers_on_user_id"
  end

  create_table "matches", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "contester1_id"
    t.integer "contester2_id"
    t.integer "score1"
    t.integer "score2"
    t.datetime "match_time"
    t.integer "challenge_id"
    t.integer "contest_id"
    t.text "report", collation: "utf8_swedish_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "map1_id"
    t.integer "map2_id"
    t.integer "server_id"
    t.integer "motm_id"
    t.integer "demo_id"
    t.integer "week_id"
    t.integer "referee_id"
    t.boolean "forfeit"
    t.integer "diff"
    t.integer "points1"
    t.integer "points2"
    t.integer "hltv_id"
    t.string "caster_id"
    t.index ["challenge_id"], name: "index_matches_on_challenge_id"
    t.index ["contest_id"], name: "index_matches_on_contest_id"
    t.index ["contester1_id"], name: "index_matches_on_contester1_id"
    t.index ["contester2_id"], name: "index_matches_on_contester2_id"
    t.index ["demo_id"], name: "index_matches_on_demo_id"
    t.index ["hltv_id"], name: "index_matches_on_hltv_id"
    t.index ["map1_id"], name: "index_matches_on_map1_id"
    t.index ["map2_id"], name: "index_matches_on_map2_id"
    t.index ["match_time"], name: "index_matches_on_match_time"
    t.index ["motm_id"], name: "index_matches_on_motm_id"
    t.index ["referee_id"], name: "index_matches_on_referee_id"
    t.index ["score1", "score2"], name: "index_matches_on_score1_and_score2"
    t.index ["server_id"], name: "index_matches_on_server_id"
    t.index ["week_id"], name: "index_matches_on_week_id"
  end

  create_table "messages", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "sender_type"
    t.integer "sender_id"
    t.string "recipient_type"
    t.integer "recipient_id"
    t.string "title"
    t.text "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "text_parsed"
    t.index ["recipient_id", "recipient_type"], name: "index_messages_on_recipient_id_and_recipient_type"
    t.index ["sender_id", "sender_type"], name: "index_messages_on_sender_id_and_sender_type"
  end

  create_table "movies", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.string "content"
    t.string "format"
    t.integer "user_id"
    t.integer "file_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "picture"
    t.integer "preview_id"
    t.integer "length"
    t.integer "match_id"
    t.integer "status"
    t.integer "category_id"
    t.index ["file_id"], name: "index_movies_on_file_id"
    t.index ["match_id"], name: "index_movies_on_match_id"
    t.index ["preview_id"], name: "index_movies_on_preview_id"
    t.index ["status"], name: "index_movies_on_status"
    t.index ["user_id"], name: "index_movies_on_user_id"
  end

  create_table "options", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "option"
    t.integer "poll_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "votes", default: 0, null: false
    t.index ["poll_id"], name: "index_options_on_poll_id"
  end

  create_table "pcws", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "team_id"
    t.integer "user_id"
    t.datetime "match_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["match_time"], name: "index_pcws_on_match_time"
    t.index ["team_id"], name: "index_pcws_on_team_id"
    t.index ["user_id"], name: "index_pcws_on_user_id"
  end

  create_table "polls", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "question"
    t.datetime "end_date"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "votes", default: 0, null: false
    t.index ["user_id"], name: "index_polls_on_user_id"
  end

  create_table "posts", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.text "text"
    t.integer "topic_id"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "text_parsed"
    t.index ["topic_id"], name: "index_posts_on_topic_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "predictions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "match_id"
    t.integer "user_id"
    t.integer "score1"
    t.integer "score2"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "result"
    t.index ["match_id"], name: "index_predictions_on_match_id"
    t.index ["user_id"], name: "index_predictions_on_user_id"
  end

  create_table "profiles", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.string "msn"
    t.string "icq"
    t.string "irc"
    t.string "web"
    t.string "town"
    t.string "singleplayer"
    t.string "multiplayer"
    t.string "food"
    t.string "beverage"
    t.string "hobby"
    t.string "music"
    t.string "book"
    t.string "movie"
    t.string "tvseries"
    t.string "res"
    t.string "sensitivity"
    t.string "monitor_hz"
    t.string "scripts"
    t.string "cpu"
    t.string "gpu"
    t.string "ram"
    t.string "psu"
    t.string "motherboard"
    t.string "soundcard"
    t.string "hdd"
    t.string "case"
    t.string "monitor"
    t.string "mouse"
    t.string "mouse_pad"
    t.string "keyboard"
    t.string "head_phones"
    t.string "speakers"
    t.text "achievements"
    t.datetime "updated_at"
    t.string "signature"
    t.string "avatar"
    t.string "clan_search"
    t.boolean "notify_news"
    t.boolean "notify_articles"
    t.boolean "notify_movies"
    t.boolean "notify_gather"
    t.boolean "notify_own_match"
    t.boolean "notify_any_match"
    t.boolean "notify_pms", default: true, null: false
    t.boolean "notify_challenge", default: true, null: false
    t.string "steam_profile"
    t.string "achievements_parsed", limit: 400
    t.text "signature_parsed"
    t.string "stream"
    t.string "layout"
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "rates", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "score"
  end

  create_table "ratings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.integer "rate_id"
    t.integer "rateable_id"
    t.string "rateable_type", limit: 32
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["rate_id"], name: "index_ratings_on_rate_id"
    t.index ["rateable_id", "rateable_type"], name: "index_ratings_on_rateable_id_and_rateable_type"
  end

  create_table "read_marks", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "readable_type", null: false
    t.integer "readable_id"
    t.string "reader_type", null: false
    t.integer "reader_id"
    t.datetime "timestamp"
    t.index ["readable_type", "readable_id"], name: "index_read_marks_on_readable_type_and_readable_id"
    t.index ["reader_id", "reader_type", "readable_type", "readable_id"], name: "read_marks_reader_readable_index", unique: true
    t.index ["reader_type", "reader_id"], name: "index_read_marks_on_reader_type_and_reader_id"
  end

  create_table "readings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "readable_type"
    t.integer "readable_id"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["readable_type", "readable_id"], name: "index_readings_on_readable_type_and_readable_id"
    t.index ["user_id", "readable_id", "readable_type"], name: "index_readings_on_user_id_and_readable_id_and_readable_type"
    t.index ["user_id"], name: "index_readings_on_user_id"
  end

  create_table "rounders", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "round_id"
    t.integer "user_id"
    t.integer "team"
    t.string "roles"
    t.integer "kills"
    t.integer "deaths"
    t.string "name"
    t.string "steamid"
    t.integer "team_id"
    t.index ["round_id"], name: "index_rounders_on_round_id"
    t.index ["team_id"], name: "index_rounders_on_team_id"
    t.index ["user_id"], name: "index_rounders_on_user_id"
  end

  create_table "rounds", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.integer "server_id"
    t.datetime "start"
    t.datetime "end"
    t.integer "winner"
    t.integer "match_id"
    t.integer "commander_id"
    t.integer "team1_id"
    t.integer "team2_id"
    t.string "map_name"
    t.integer "map_id"
    t.index ["commander_id"], name: "index_rounds_on_commander_id"
    t.index ["map_id"], name: "index_rounds_on_map_id"
    t.index ["match_id"], name: "index_rounds_on_match_id"
    t.index ["server_id"], name: "index_rounds_on_server_id"
    t.index ["team1_id"], name: "index_rounds_on_team1_id"
    t.index ["team2_id"], name: "index_rounds_on_team2_id"
  end

  create_table "server_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "server_id"
    t.integer "version"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "map"
    t.integer "players"
    t.integer "max_players"
    t.string "ping"
    t.integer "category_id"
    t.index ["server_id"], name: "index_server_versions_on_server_id"
  end

  create_table "servers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "dns"
    t.string "ip"
    t.string "port"
    t.string "password"
    t.string "irc"
    t.integer "user_id"
    t.boolean "official"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "map"
    t.integer "players"
    t.integer "max_players"
    t.string "ping"
    t.integer "version"
    t.integer "domain", default: 0, null: false
    t.string "reservation"
    t.string "recording"
    t.datetime "idle"
    t.integer "default_id"
    t.boolean "active", default: true, null: false
    t.string "recordable_type"
    t.integer "recordable_id"
    t.integer "category_id"
    t.index ["default_id"], name: "index_servers_on_default_id"
    t.index ["players", "domain"], name: "index_servers_on_players_and_domain"
    t.index ["user_id"], name: "index_servers_on_user_id"
  end

  create_table "sessions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data", size: :long
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "shoutmsg_archive", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.string "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "shoutable_type"
    t.integer "shoutable_id"
    t.index ["shoutable_type", "shoutable_id"], name: "index_shoutmsgs_on_shoutable_type_and_shoutable_id"
    t.index ["user_id"], name: "index_shoutmsgs_on_user_id"
  end

  create_table "shoutmsgs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.string "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "shoutable_type"
    t.integer "shoutable_id"
    t.index ["shoutable_type", "shoutable_id"], name: "index_shoutmsgs_on_shoutable_type_and_shoutable_id"
    t.index ["user_id"], name: "index_shoutmsgs_on_user_id"
  end

  create_table "sites", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.integer "category_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "favicon"
    t.index ["category_id"], name: "index_sites_on_category_id"
    t.index ["created_at"], name: "index_sites_on_created_at"
  end

  create_table "teamers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "team_id", null: false
    t.integer "user_id", null: false
    t.string "comment"
    t.integer "rank", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["team_id"], name: "index_teamers_on_team_id"
    t.index ["user_id"], name: "index_teamers_on_user_id"
  end

  create_table "teams", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.string "irc"
    t.string "web"
    t.string "tag"
    t.string "country"
    t.string "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "logo"
    t.integer "founder_id"
    t.boolean "active", default: true, null: false
    t.string "recruiting"
    t.integer "teamers_count"
    t.index ["founder_id"], name: "index_teams_on_founder_id"
  end

  create_table "topics", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci", force: :cascade do |t|
    t.string "title"
    t.integer "user_id"
    t.integer "forum_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "state", default: 0, null: false
    t.index ["forum_id"], name: "index_topics_on_forum_id"
    t.index ["user_id"], name: "index_topics_on_user_id"
  end

  create_table "user_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.integer "version"
    t.string "steamid"
    t.string "username"
    t.string "lastip"
    t.datetime "updated_at"
    t.index ["steamid"], name: "index_user_versions_on_steamid"
    t.index ["user_id"], name: "index_user_versions_on_user_id"
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "username", collation: "utf8_bin"
    t.string "password"
    t.string "firstname"
    t.string "lastname"
    t.string "email"
    t.string "steamid"
    t.integer "team_id"
    t.datetime "lastvisit"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "lastip"
    t.string "country"
    t.date "birthdate"
    t.string "time_zone"
    t.integer "version"
    t.boolean "public_email", default: false, null: false
    t.index ["lastvisit"], name: "index_users_on_lastvisit"
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  create_table "versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "view_counts", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "viewable_id"
    t.string "viewable_type"
    t.string "ip_address"
    t.boolean "logged_in"
    t.date "created_at"
    t.index ["viewable_type", "viewable_id"], name: "index_view_counts_on_viewable_type_and_viewable_id"
  end

  create_table "votes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.integer "votable_id"
    t.integer "poll_id"
    t.string "votable_type"
    t.index ["user_id"], name: "index_votes_on_user_id"
    t.index ["votable_id", "votable_type"], name: "index_votes_on_votable_id_and_votable_type"
  end

  create_table "watchers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "user_id"
    t.integer "movie_id"
    t.boolean "banned", default: false, null: false
    t.datetime "updated_at"
    t.index ["movie_id"], name: "index_watchers_on_movie_id"
    t.index ["user_id"], name: "index_watchers_on_user_id"
  end

  create_table "weeks", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name"
    t.date "start_date"
    t.integer "contest_id"
    t.integer "map1_id"
    t.integer "map2_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["contest_id"], name: "index_weeks_on_contest_id"
    t.index ["map1_id"], name: "index_weeks_on_map1_id"
    t.index ["map2_id"], name: "index_weeks_on_map2_id"
  end

end
