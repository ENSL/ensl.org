import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Values are passed from the gather page via data-* attributes.
  static values = { gatherId: Number, version: Number, pollInterval: Number, deadReloadAfter: Number }

  // Start polling the version endpoint and listen for visibility/online recovery.
  connect() {
    // Poll every few seconds, and also re-check when tab becomes visible/online.
    const interval = this.pollIntervalValue || 8000

    // deadSinceAt: first time we detected failed sync.
    // deadReloadTimer: one-shot timer to force a hard reload if failures persist.
    // isReloading: guard to avoid reloading multiple times.
    this.deadSinceAt = null
    this.deadReloadTimer = null
    this.isReloading = false
    this.checkInFlight = false
    this.lastCheckAt = 0

    this.poll = setInterval(() => this.checkVersion(), interval)
    this.checkVersion()
    this.onVisibilityChange = () => {
      if (!document.hidden) this.checkVersion()
    }
    this.onOnline = () => this.checkVersion()

    document.addEventListener("visibilitychange", this.onVisibilityChange)
    window.addEventListener("online", this.onOnline)
  }

  // Stop timers and listeners when the controller disconnects.
  disconnect() {
    clearInterval(this.poll)
    this.clearDeadReloadTimer()
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    window.removeEventListener("online", this.onOnline)
  }

  // Ask the server whether the gather content version has changed.
  async checkVersion() {
    if (this.checkInFlight) return

    const now = Date.now()
    // Coalesce bursty triggers (poll + visibility + online) into one request.
    if ((now - this.lastCheckAt) < 300) return

    this.checkInFlight = true
    this.lastCheckAt = now

    // Lightweight endpoint that tells us whether gather content changed.
    try {
      const res = await fetch(`/gathers/${this.gatherIdValue}/version`, {
        headers: { "Accept": "application/json" }
      })
      if (!res.ok) {
        this.trackDeadConnection()
        return
      }

      this.markConnectionAlive()
      const data = await res.json()
      if (data.version !== this.currentDomVersion()) {
        this.reloadFrameOrPage()
      }
    } catch (e) {
      this.trackDeadConnection()
    } finally {
      this.checkInFlight = false
    }
  }

  // Clear the dead-connection state after any successful version check.
  markConnectionAlive() {
    // Any successful check means connection is healthy again.
    this.deadSinceAt = null
    this.clearDeadReloadTimer()
  }

  // Track failed checks and escalate to a hard reload if the outage lasts too long.
  trackDeadConnection() {
    if (this.isReloading) return

    // On first failure, start the watchdog timer.
    if (!this.deadSinceAt) {
      this.deadSinceAt = Date.now()
      this.scheduleDeadReload()
      return
    }

    const threshold = this.deadReloadAfterValue || (10 * 60 * 1000)
    if ((Date.now() - this.deadSinceAt) >= threshold) {
      this.forceHardReload()
    }
  }

  // Arm the watchdog timer that eventually forces a reload after repeated failures.
  scheduleDeadReload() {
    // Force a hard reload if we stay disconnected for too long.
    this.clearDeadReloadTimer()
    const threshold = this.deadReloadAfterValue || (10 * 60 * 1000)
    this.deadReloadTimer = setTimeout(() => {
      if (this.deadSinceAt && !this.isReloading) {
        this.forceHardReload()
      }
    }, threshold)
  }

  // Cancel the watchdog timer when the connection comes back.
  clearDeadReloadTimer() {
    if (this.deadReloadTimer) {
      clearTimeout(this.deadReloadTimer)
      this.deadReloadTimer = null
    }
  }

  // Broadcast a reload event and refresh the page when sync is considered dead.
  forceHardReload() {
    if (this.isReloading) return

    // Emit an event (useful for tests/telemetry) and reload the page.
    this.isReloading = true
    window.dispatchEvent(new CustomEvent("gather-sync:force-reload", {
      detail: {
        gatherId: this.gatherIdValue,
        deadForMs: Date.now() - (this.deadSinceAt || Date.now())
      }
    }))
    window.location.reload()
  }

  // Read the version marker from the DOM so we can compare it with the server.
  currentDomVersion() {
    // Current version marker rendered in the page.
    const el = document.querySelector(`#gather_${this.gatherIdValue}_version`)
    const v = el?.dataset?.version
    return v ? parseInt(v, 10) : this.versionValue
  }

  // Reload just the gather frame when possible, otherwise fall back to a full reload.
  reloadFrameOrPage() {
    // Prefer reloading only the gather frame; fallback to full page reload.
    const frame = document.getElementById(`gather_${this.gatherIdValue}_frame`)
    if (frame && typeof frame.reload === "function") {
      frame.reload()
      return
    }
    if (frame && frame.dataset && frame.dataset.src) {
      frame.src = frame.dataset.src
      return
    }
    if (frame && frame.src) {
      frame.src = frame.src
      return
    }
    window.location.reload()
  }
}
