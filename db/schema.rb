# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_12_130000) do
  create_table "analysis_results", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "batch_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "metric", null: false
    t.integer "milestone"
    t.string "model", null: false
    t.string "steamid"
    t.float "value", null: false
    t.index ["batch_id", "model", "metric", "steamid", "milestone"], name: "index_analysis_results_on_batch_and_subject", unique: true
    t.index ["batch_id"], name: "index_analysis_results_on_batch_id"
    t.index ["model", "metric"], name: "index_analysis_results_on_model_and_metric"
    t.index ["steamid"], name: "index_analysis_results_on_steamid"
  end

  create_table "articles", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.integer "status", null: false
    t.text "text", size: :long
    t.integer "text_coding", default: 0, null: false
    t.text "text_parsed", size: :long
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "version"
    t.index ["category_id"], name: "index_articles_on_category_id"
    t.index ["created_at", "status"], name: "index_articles_on_created_at_and_status"
    t.index ["created_at"], name: "index_articles_on_created_at"
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "bans", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "addr"
    t.integer "ban_type"
    t.datetime "created_at", precision: nil
    t.integer "creator_id"
    t.datetime "expiry", precision: nil
    t.string "ip"
    t.string "reason"
    t.integer "server_id"
    t.string "steamid"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["creator_id"], name: "index_bans_on_creator_id"
    t.index ["server_id"], name: "index_bans_on_server_id"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "bracketers", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "bracket_id"
    t.integer "column"
    t.datetime "created_at", precision: nil
    t.string "custom_text"
    t.boolean "disabled"
    t.integer "match_id"
    t.integer "row"
    t.integer "team_id"
    t.datetime "updated_at", precision: nil
    t.index ["bracket_id"], name: "index_bracketers_on_bracket_id"
    t.index ["match_id"], name: "index_bracketers_on_match_id"
    t.index ["team_id"], name: "index_bracketers_on_team_id"
  end

  create_table "brackets", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "contest_id"
    t.datetime "created_at", precision: nil
    t.string "name"
    t.integer "slots"
    t.datetime "updated_at", precision: nil
    t.index ["contest_id"], name: "index_brackets_on_contest_id"
  end

  create_table "categories", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "domain"
    t.string "name"
    t.integer "sort"
    t.datetime "updated_at", precision: nil
    t.index ["domain"], name: "index_categories_on_domain"
    t.index ["sort"], name: "index_categories_on_sort"
  end

  create_table "challenges", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "contester1_id"
    t.integer "contester2_id"
    t.datetime "created_at", precision: nil
    t.datetime "default_time", precision: nil
    t.string "details"
    t.boolean "mandatory"
    t.string "map1_id"
    t.string "map2_id"
    t.datetime "match_time", precision: nil
    t.string "response"
    t.integer "server_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["contester1_id"], name: "index_challenges_on_contester1_id"
    t.index ["contester2_id"], name: "index_challenges_on_contester2_id"
    t.index ["map1_id"], name: "index_challenges_on_map1_id"
    t.index ["map2_id"], name: "index_challenges_on_map2_id"
    t.index ["server_id"], name: "index_challenges_on_server_id"
    t.index ["user_id"], name: "index_challenges_on_user_id"
  end

  create_table "comments", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "commentable_id"
    t.string "commentable_type"
    t.datetime "created_at", precision: nil
    t.text "text", size: :medium
    t.text "text_parsed", size: :medium
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["commentable_type", "id"], name: "index_comments_on_commentable_type_and_id"
    t.index ["commentable_type"], name: "index_comments_on_commentable_type"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "contesters", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "contest_id"
    t.datetime "created_at", precision: nil
    t.integer "draw", default: 0, null: false
    t.integer "extra", null: false
    t.integer "loss", default: 0, null: false
    t.integer "score", default: 0, null: false
    t.integer "team_id"
    t.integer "trend", null: false
    t.datetime "updated_at", precision: nil
    t.integer "win", default: 0, null: false
    t.index ["contest_id"], name: "index_contesters_on_contest_id"
    t.index ["team_id", "contest_id"], name: "index_contesters_on_team_id_and_contest_id_unique", unique: true
    t.index ["team_id"], name: "index_contesters_on_team_id"
  end

  create_table "contests", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "contest_type", default: 0, null: false
    t.datetime "created_at", precision: nil
    t.time "default_time"
    t.integer "demos_id"
    t.datetime "end", precision: nil
    t.float "modulus_3to1"
    t.float "modulus_4to0"
    t.integer "modulus_base"
    t.float "modulus_even"
    t.string "name"
    t.integer "rules_id"
    t.string "short_name"
    t.datetime "start", precision: nil
    t.integer "status"
    t.datetime "updated_at", precision: nil
    t.integer "weight"
    t.integer "winner_id"
    t.index ["demos_id"], name: "index_contests_on_demos_id"
    t.index ["rules_id"], name: "index_contests_on_rules_id"
    t.index ["status"], name: "index_contests_on_status"
    t.index ["winner_id"], name: "index_contests_on_winner_id"
  end

  create_table "contests_maps", id: false, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "contest_id"
    t.integer "map_id"
    t.index ["contest_id", "map_id"], name: "index_contests_maps_on_contest_id_and_map_id"
    t.index ["map_id", "contest_id"], name: "index_contests_maps_on_map_id_and_contest_id"
  end

  create_table "custom_urls", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "article_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["article_id"], name: "index_custom_urls_on_article_id"
    t.index ["name"], name: "index_custom_urls_on_name", unique: true
  end

  create_table "data_files", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "article_id"
    t.datetime "created_at", precision: nil
    t.text "description", default: "", null: false
    t.integer "directory_id"
    t.string "md5"
    t.string "name"
    t.string "path"
    t.integer "related_id"
    t.integer "size", null: false
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.index ["article_id"], name: "index_data_files_on_article_id"
    t.index ["directory_id"], name: "index_data_files_on_directory_id"
    t.index ["related_id"], name: "index_data_files_on_related_id"
  end

  create_table "directories", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "description"
    t.boolean "hidden", default: false, null: false
    t.string "name"
    t.integer "parent_id"
    t.string "path"
    t.bigint "st_dev", comment: "Filesystem device ID for inode tracking"
    t.bigint "st_ino", comment: "Inode number for filesystem-independent directory identification"
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.index ["parent_id"], name: "index_directories_on_parent_id"
    t.index ["st_dev", "st_ino"], name: "index_directories_on_inode", unique: true
  end

  create_table "forumers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.integer "access"
    t.datetime "created_at", precision: nil
    t.integer "forum_id"
    t.integer "group_id"
    t.datetime "updated_at", precision: nil
    t.index ["forum_id"], name: "index_forumers_on_forum_id"
    t.index ["group_id", "forum_id", "access"], name: "index_forumers_on_group_id_forum_id_access_unique", unique: true
    t.index ["group_id"], name: "index_forumers_on_group_id"
  end

  create_table "forums", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.string "description"
    t.integer "position"
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.index ["category_id"], name: "index_forums_on_category_id"
  end

  create_table "gather_maps", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.integer "gather_id"
    t.integer "map_id"
    t.integer "votes"
    t.index ["gather_id"], name: "index_gather_maps_on_gather_id"
    t.index ["map_id"], name: "index_gather_maps_on_map_id"
  end

  create_table "gather_servers", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "gather_id"
    t.integer "server_id"
    t.datetime "updated_at", precision: nil
    t.integer "votes"
    t.index ["gather_id"], name: "index_gather_servers_on_gather_id"
    t.index ["server_id"], name: "index_gather_servers_on_server_id"
  end

  create_table "gatherers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "gather_id"
    t.integer "pick_order"
    t.integer "status", default: 0, null: false
    t.integer "team"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "votes", default: 0, null: false
    t.index ["gather_id", "pick_order"], name: "index_gatherers_on_gather_id_and_pick_order"
    t.index ["gather_id"], name: "index_gatherers_on_gather_id"
    t.index ["updated_at", "gather_id"], name: "index_gatherers_on_updated_at_and_gather_id"
    t.index ["user_id", "gather_id"], name: "index_gatherers_on_user_id_and_gather_id_unique", unique: true
    t.index ["user_id"], name: "index_gatherers_on_user_id"
  end

  create_table "gathers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.integer "captain1_id"
    t.integer "captain2_id"
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.datetime "lastpick1", precision: nil
    t.datetime "lastpick2", precision: nil
    t.integer "map1_id"
    t.integer "map2_id"
    t.string "pick_strategy", default: "1-2-2-2-2-1", null: false
    t.integer "server_id"
    t.integer "status"
    t.integer "turn"
    t.datetime "updated_at", precision: nil
    t.integer "version", default: 0, null: false
    t.integer "votes", default: 0, null: false
    t.index ["captain1_id"], name: "index_gathers_on_captain1_id"
    t.index ["captain2_id"], name: "index_gathers_on_captain2_id"
    t.index ["category_id"], name: "index_gathers_on_category_id"
    t.index ["map1_id"], name: "index_gathers_on_map1_id"
    t.index ["map2_id"], name: "index_gathers_on_map2_id"
    t.index ["server_id"], name: "index_gathers_on_server_id"
    t.index ["version"], name: "index_gathers_on_version"
  end

  create_table "gathers_users", id: false, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.integer "gather_id", null: false
    t.integer "user_id", null: false
    t.index ["gather_id"], name: "index_gathers_users_on_gather_id"
    t.index ["user_id"], name: "index_gathers_users_on_user_id"
  end

  create_table "groupers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "group_id"
    t.string "task"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["group_id"], name: "index_groupers_on_group_id"
    t.index ["user_id", "group_id"], name: "index_groupers_on_user_id_and_group_id_unique", unique: true
    t.index ["user_id"], name: "index_groupers_on_user_id"
  end

  create_table "groups", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "founder_id"
    t.string "name"
    t.datetime "updated_at", precision: nil
    t.index ["founder_id"], name: "index_groups_on_founder_id"
  end

  create_table "groups_users", id: false, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id", null: false
    t.index ["group_id"], name: "index_groups_users_on_group_id"
    t.index ["user_id"], name: "index_groups_users_on_user_id"
  end

  create_table "issues", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "assigned_id"
    t.integer "author_id"
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.text "solution", size: :medium
    t.integer "status"
    t.text "text", size: :medium
    t.text "text_parsed", size: :medium
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.index ["assigned_id"], name: "index_issues_on_assigned_id"
    t.index ["author_id"], name: "index_issues_on_author_id"
    t.index ["category_id"], name: "index_issues_on_category_id"
  end

  create_table "locks", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "lockable_id"
    t.string "lockable_type", collation: "utf8mb3_general_ci"
    t.datetime "updated_at", precision: nil
    t.index ["lockable_id", "lockable_type"], name: "index_locks_on_lockable_id_and_lockable_type"
  end

  create_table "log_events", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "description"
    t.string "name"
    t.integer "team"
    t.datetime "updated_at", precision: nil
  end

  create_table "log_files", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.string "md5"
    t.string "name"
    t.integer "server_id"
    t.integer "size"
    t.datetime "updated_at", precision: nil
    t.index ["server_id"], name: "index_log_files_on_server_id"
  end

  create_table "log_lines", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "actor_id"
    t.datetime "created_at", precision: nil
    t.string "details"
    t.integer "domain"
    t.integer "log_file_id"
    t.integer "round_id"
    t.integer "server_id"
    t.string "specifics1"
    t.string "specifics2"
    t.integer "target_id"
    t.text "text"
    t.index ["actor_id"], name: "index_log_lines_on_actor_id"
    t.index ["log_file_id"], name: "index_log_lines_on_log_file_id"
    t.index ["round_id"], name: "index_log_lines_on_round_id"
    t.index ["server_id"], name: "index_log_lines_on_server_id"
    t.index ["target_id"], name: "index_log_lines_on_target_id"
  end

  create_table "maps", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.boolean "deleted", default: false, null: false
    t.string "download"
    t.string "name"
    t.string "picture"
    t.datetime "updated_at", precision: nil
    t.index ["category_id"], name: "index_maps_on_category_id"
  end

  create_table "match_proposals", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "match_id"
    t.datetime "proposed_time", precision: nil
    t.integer "status"
    t.integer "team_id"
    t.index ["match_id"], name: "index_match_proposals_on_match_id"
    t.index ["status"], name: "index_match_proposals_on_status"
    t.index ["team_id"], name: "index_match_proposals_on_team_id"
  end

  create_table "matchers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "contester_id", null: false
    t.datetime "created_at", precision: nil
    t.integer "match_id", null: false
    t.boolean "merc", null: false
    t.datetime "updated_at", precision: nil
    t.integer "user_id", null: false
    t.index ["contester_id"], name: "index_matchers_on_contester_id"
    t.index ["match_id"], name: "index_matchers_on_match_id"
    t.index ["user_id"], name: "index_matchers_on_user_id"
  end

  create_table "matches", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "caster_id"
    t.integer "challenge_id"
    t.integer "contest_id"
    t.integer "contester1_id"
    t.integer "contester2_id"
    t.datetime "created_at", precision: nil
    t.integer "demo_id"
    t.integer "diff"
    t.boolean "forfeit"
    t.integer "hltv_id"
    t.integer "map1_id"
    t.integer "map2_id"
    t.datetime "match_time", precision: nil
    t.integer "motm_id"
    t.integer "points1"
    t.integer "points2"
    t.integer "referee_id"
    t.text "report", collation: "utf8mb3_swedish_ci"
    t.integer "score1"
    t.integer "score2"
    t.integer "server_id"
    t.datetime "updated_at", precision: nil
    t.integer "week_id"
    t.index ["caster_id"], name: "index_matches_on_caster_id"
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

  create_table "messages", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "recipient_id"
    t.string "recipient_type"
    t.integer "sender_id"
    t.string "sender_type"
    t.text "text", size: :medium
    t.text "text_parsed", size: :medium
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.index ["recipient_id", "recipient_type"], name: "index_messages_on_recipient_id_and_recipient_type"
    t.index ["sender_id", "sender_type"], name: "index_messages_on_sender_id_and_sender_type"
  end

  create_table "movies", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "category_id"
    t.string "content"
    t.datetime "created_at", precision: nil
    t.integer "file_id"
    t.string "format"
    t.integer "length"
    t.integer "match_id"
    t.text "metadata", size: :long, collation: "utf8mb4_bin"
    t.string "name"
    t.string "picture"
    t.integer "preview_id"
    t.integer "status"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.boolean "web_friendly", default: false, null: false
    t.index ["category_id"], name: "index_movies_on_category_id"
    t.index ["file_id"], name: "index_movies_on_file_id"
    t.index ["match_id"], name: "index_movies_on_match_id"
    t.index ["preview_id"], name: "index_movies_on_preview_id"
    t.index ["status"], name: "index_movies_on_status"
    t.index ["user_id"], name: "index_movies_on_user_id"
    t.check_constraint "json_valid(`metadata`)", name: "metadata"
  end

  create_table "options", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "option"
    t.integer "poll_id"
    t.datetime "updated_at", precision: nil
    t.integer "votes", default: 0, null: false
    t.index ["poll_id"], name: "index_options_on_poll_id"
  end

  create_table "passkey_credentials", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "external_id", null: false
    t.datetime "last_used_at", precision: nil
    t.text "public_key", size: :medium, null: false
    t.bigint "sign_count", default: 0, null: false
    t.datetime "updated_at", precision: nil
    t.integer "user_id", null: false
    t.index ["external_id"], name: "index_passkey_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_passkey_credentials_on_user_id"
  end

  create_table "pcws", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "match_time", precision: nil
    t.integer "team_id"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["match_time"], name: "index_pcws_on_match_time"
    t.index ["team_id"], name: "index_pcws_on_team_id"
    t.index ["user_id"], name: "index_pcws_on_user_id"
  end

  create_table "polls", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "end_date", precision: nil
    t.string "question"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "votes", default: 0, null: false
    t.index ["user_id"], name: "index_polls_on_user_id"
  end

  create_table "posts", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "text", size: :medium
    t.text "text_parsed", size: :medium
    t.integer "topic_id"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["topic_id"], name: "index_posts_on_topic_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "predictions", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "match_id"
    t.integer "result"
    t.integer "score1"
    t.integer "score2"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["match_id", "user_id"], name: "index_predictions_on_match_id_and_user_id_unique", unique: true
    t.index ["match_id"], name: "index_predictions_on_match_id"
    t.index ["user_id"], name: "index_predictions_on_user_id"
  end

  create_table "profiles", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.text "achievements", size: :medium
    t.string "achievements_parsed", limit: 400
    t.string "avatar"
    t.string "beverage"
    t.string "book"
    t.string "case"
    t.string "clan_search"
    t.string "cpu"
    t.string "food"
    t.string "gpu"
    t.string "hdd"
    t.string "head_phones"
    t.string "hobby"
    t.string "icq"
    t.string "irc"
    t.string "keyboard"
    t.string "layout"
    t.string "monitor"
    t.string "monitor_hz"
    t.string "motherboard"
    t.string "mouse"
    t.string "mouse_pad"
    t.string "movie"
    t.string "msn"
    t.string "multiplayer"
    t.string "music"
    t.boolean "notify_any_match"
    t.boolean "notify_articles"
    t.boolean "notify_challenge", default: true, null: false
    t.boolean "notify_gather"
    t.boolean "notify_movies"
    t.boolean "notify_news"
    t.boolean "notify_own_match"
    t.boolean "notify_pms", default: true, null: false
    t.string "psu"
    t.string "ram"
    t.string "res"
    t.string "scripts"
    t.string "sensitivity"
    t.string "signature"
    t.text "signature_parsed", size: :medium
    t.string "singleplayer"
    t.string "soundcard"
    t.string "speakers"
    t.string "steam_profile"
    t.string "stream"
    t.string "town"
    t.string "tvseries"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.string "web"
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "rates", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "score"
  end

  create_table "ratings", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "rate_id"
    t.integer "rateable_id"
    t.string "rateable_type", limit: 32
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["rate_id"], name: "index_ratings_on_rate_id"
    t.index ["rateable_id", "rateable_type"], name: "index_ratings_on_rateable_id_and_rateable_type"
    t.index ["user_id"], name: "index_ratings_on_user_id"
  end

  create_table "read_marks", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "readable_id"
    t.string "readable_type", null: false
    t.bigint "reader_id", null: false
    t.string "reader_type", null: false
    t.datetime "timestamp", precision: nil
    t.index ["reader_id", "reader_type", "readable_type", "readable_id"], name: "read_marks_reader_readable_index", unique: true
  end

  create_table "readings", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "readable_id"
    t.string "readable_type"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["readable_type", "readable_id"], name: "index_readings_on_readable_type_and_readable_id"
    t.index ["user_id", "readable_id", "readable_type"], name: "index_readings_on_user_id_and_readable_id_and_readable_type"
    t.index ["user_id"], name: "index_readings_on_user_id"
  end

  create_table "rounders", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.integer "deaths"
    t.integer "kills"
    t.string "name"
    t.string "roles"
    t.integer "round_id"
    t.string "steamid"
    t.integer "team"
    t.integer "team_id"
    t.integer "user_id"
    t.index ["round_id"], name: "index_rounders_on_round_id"
    t.index ["team_id"], name: "index_rounders_on_team_id"
    t.index ["user_id"], name: "index_rounders_on_user_id"
  end

  create_table "rounds", id: :integer, charset: "utf8mb3", collation: "utf8mb3_swedish_ci", force: :cascade do |t|
    t.integer "commander_id"
    t.datetime "end", precision: nil
    t.integer "map_id"
    t.string "map_name"
    t.integer "match_id"
    t.integer "server_id"
    t.datetime "start", precision: nil
    t.integer "team1_id"
    t.integer "team2_id"
    t.integer "winner"
    t.index ["commander_id"], name: "index_rounds_on_commander_id"
    t.index ["map_id"], name: "index_rounds_on_map_id"
    t.index ["match_id"], name: "index_rounds_on_match_id"
    t.index ["server_id"], name: "index_rounds_on_server_id"
    t.index ["team1_id"], name: "index_rounds_on_team1_id"
    t.index ["team2_id"], name: "index_rounds_on_team2_id"
  end

  create_table "server_versions", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.string "map"
    t.integer "max_players"
    t.string "ping"
    t.integer "players"
    t.integer "server_id"
    t.string "status", default: "offline", null: false
    t.datetime "updated_at", precision: nil
    t.integer "version"
    t.index ["category_id"], name: "index_server_versions_on_category_id"
    t.index ["server_id"], name: "index_server_versions_on_server_id"
  end

  create_table "servers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.integer "default_id"
    t.string "description"
    t.string "dns"
    t.integer "domain", default: 0, null: false
    t.datetime "idle", precision: nil
    t.string "ip"
    t.string "map"
    t.integer "max_players"
    t.string "name"
    t.boolean "official"
    t.string "password"
    t.string "ping"
    t.integer "players"
    t.string "port"
    t.integer "recordable_id"
    t.string "recordable_type"
    t.string "recording"
    t.string "reservation"
    t.string "status", default: "offline", null: false
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "version"
    t.index ["category_id"], name: "index_servers_on_category_id"
    t.index ["default_id"], name: "index_servers_on_default_id"
    t.index ["players", "domain"], name: "index_servers_on_players_and_domain"
    t.index ["recordable_id", "recordable_type"], name: "index_servers_on_recordable_id_and_recordable_type"
    t.index ["user_id"], name: "index_servers_on_user_id"
  end

  create_table "sessions", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "data", size: :long
    t.string "session_id", null: false
    t.datetime "updated_at", precision: nil
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "shoutmsg_archive", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "shoutable_id"
    t.string "shoutable_type"
    t.string "text"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["shoutable_type", "shoutable_id"], name: "index_shoutmsgs_on_shoutable_type_and_shoutable_id"
    t.index ["user_id"], name: "index_shoutmsgs_on_user_id"
  end

  create_table "shoutmsgs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "shoutable_id"
    t.string "shoutable_type"
    t.string "text"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["shoutable_type", "shoutable_id"], name: "index_shoutmsgs_on_shoutable_type_and_shoutable_id"
    t.index ["user_id"], name: "index_shoutmsgs_on_user_id"
  end

  create_table "sites", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", precision: nil
    t.string "favicon"
    t.string "name"
    t.datetime "updated_at", precision: nil
    t.string "url"
    t.index ["category_id"], name: "index_sites_on_category_id"
    t.index ["created_at"], name: "index_sites_on_created_at"
  end

  create_table "teamers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "comment"
    t.datetime "created_at", precision: nil
    t.integer "rank", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", precision: nil
    t.integer "user_id", null: false
    t.index ["team_id"], name: "index_teamers_on_team_id"
    t.index ["user_id"], name: "index_teamers_on_user_id"
  end

  create_table "teams", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "comment"
    t.string "country"
    t.datetime "created_at", precision: nil
    t.integer "founder_id"
    t.string "irc"
    t.string "logo"
    t.string "name"
    t.string "recruiting"
    t.string "tag"
    t.integer "teamers_count"
    t.datetime "updated_at", precision: nil
    t.string "web"
    t.index ["founder_id"], name: "index_teams_on_founder_id"
  end

  create_table "topics", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "forum_id"
    t.integer "state", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["forum_id"], name: "index_topics_on_forum_id"
    t.index ["user_id"], name: "index_topics_on_user_id"
  end

  create_table "users", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.date "birthdate"
    t.string "country"
    t.datetime "created_at", precision: nil
    t.string "email"
    t.string "firstname"
    t.string "lastip"
    t.string "lastname"
    t.datetime "lastvisit", precision: nil
    t.string "password"
    t.integer "password_hash", default: 1
    t.boolean "public_email", default: false, null: false
    t.string "steamid"
    t.integer "team_id"
    t.string "time_zone"
    t.datetime "updated_at", precision: nil
    t.string "username", collation: "utf8mb3_bin"
    t.integer "version"
    t.index ["lastvisit"], name: "index_users_on_lastvisit"
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  create_table "versions", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.text "object", size: :long
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "view_counts", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.date "created_at"
    t.string "ip_address"
    t.boolean "logged_in"
    t.integer "viewable_id"
    t.string "viewable_type"
    t.index ["viewable_type", "viewable_id"], name: "index_view_counts_on_viewable_type_and_viewable_id"
  end

  create_table "votes", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "poll_id"
    t.integer "user_id"
    t.integer "votable_id"
    t.string "votable_type"
    t.index ["poll_id"], name: "index_votes_on_poll_id"
    t.index ["user_id", "votable_id", "votable_type"], name: "index_votes_on_user_id_votable_unique", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
    t.index ["votable_id", "votable_type"], name: "index_votes_on_votable_id_and_votable_type"
  end

  create_table "watchers", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.boolean "banned", default: false, null: false
    t.integer "movie_id"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["movie_id"], name: "index_watchers_on_movie_id"
    t.index ["user_id"], name: "index_watchers_on_user_id"
  end

  create_table "weeks", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "contest_id"
    t.datetime "created_at", precision: nil
    t.integer "map1_id"
    t.integer "map2_id"
    t.string "name"
    t.date "start_date"
    t.datetime "updated_at", precision: nil
    t.index ["contest_id"], name: "index_weeks_on_contest_id"
    t.index ["map1_id"], name: "index_weeks_on_map1_id"
    t.index ["map2_id"], name: "index_weeks_on_map2_id"
  end
end
