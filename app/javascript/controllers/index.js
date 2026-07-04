import { application } from "controllers/application"
import GatherSyncController from "controllers/gather_sync_controller"
import EmojiAutocompleteController from "controllers/emoji_autocomplete_controller"
import TwemojiController from "controllers/twemoji_controller"
import ServerTableController from "controllers/server_table_controller"
import GatherMusicController from "controllers/gather_music_controller"
import PasskeyAuthController from "controllers/passkey_auth_controller"
import "controllers/local"
import "controllers/shoutbox"

// Register the controller classes that the app wires up through data-controller.
application.register("gather-sync", GatherSyncController)
application.register("emoji-autocomplete", EmojiAutocompleteController)
application.register("twemoji", TwemojiController)
application.register("server-table", ServerTableController)
application.register("gather-music", GatherMusicController)
application.register("passkey-auth", PasskeyAuthController)
