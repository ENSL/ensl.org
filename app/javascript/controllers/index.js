import { application } from "controllers/application"
import GatherSyncController from "controllers/gather_sync"
import EmojiAutocompleteController from "controllers/emoji_autocomplete"
import TwemojiController from "controllers/twemoji"
import ServerTableController from "controllers/server_table"
import GatherMusicController from "controllers/gather_music"
import PasskeyAuthController from "controllers/passkey_auth"
import SortableTableController from "controllers/sortable_table"
import MapBalanceChartController from "controllers/map_balance_chart"
import ArticleEditorController from "controllers/article_editor"
import ArticleFileController from "controllers/article_file"
import "legacy/local"
import "legacy/shoutbox"

// Register the controller classes that the app wires up through data-controller.
application.register("gather-sync", GatherSyncController)
application.register("emoji-autocomplete", EmojiAutocompleteController)
application.register("twemoji", TwemojiController)
application.register("server-table", ServerTableController)
application.register("gather-music", GatherMusicController)
application.register("passkey-auth", PasskeyAuthController)
application.register("sortable-table", SortableTableController)
application.register("map-balance-chart", MapBalanceChartController)
application.register("article-editor", ArticleEditorController)
application.register("article-file", ArticleFileController)
