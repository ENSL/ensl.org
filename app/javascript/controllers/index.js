import { application } from "./application"
import GatherSyncController from "./gather_sync_controller"
import EmojiAutocompleteController from "./emoji_autocomplete_controller"
import TwemojiController from "./twemoji_controller"
import ServerTableController from "./server_table_controller"
import GatherMusicController from "./gather_music_controller"
import "./local"
import "./shoutbox"

application.register("gather-sync", GatherSyncController)
application.register("emoji-autocomplete", EmojiAutocompleteController)
application.register("twemoji", TwemojiController)
application.register("server-table", ServerTableController)
application.register("gather-music", GatherMusicController)
