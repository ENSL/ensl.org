import { application } from "./application"
import GatherSyncController from "./gather_sync_controller"
import "./local"
import "./shoutbox"

application.register("gather-sync", GatherSyncController)
