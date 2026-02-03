import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { gatherId: Number, version: Number }

  connect() {
    this.poll = setInterval(() => this.checkVersion(), 8000)
    this.onVisibilityChange = () => {
      if (!document.hidden) this.checkVersion()
    }
    this.onOnline = () => this.checkVersion()

    document.addEventListener("visibilitychange", this.onVisibilityChange)
    window.addEventListener("online", this.onOnline)
  }

  disconnect() {
    clearInterval(this.poll)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    window.removeEventListener("online", this.onOnline)
  }

  async checkVersion() {
    try {
      const res = await fetch(`/gathers/${this.gatherIdValue}/version`, {
        headers: { "Accept": "application/json" }
      })
      if (!res.ok) return
      const data = await res.json()
      if (data.version !== this.currentDomVersion()) {
        this.reloadFrameOrPage()
      }
    } catch (e) {
      // ignore transient failures
    }
  }

  currentDomVersion() {
    const el = document.querySelector(`#gather_${this.gatherIdValue}_version`)
    const v = el?.dataset?.version
    return v ? parseInt(v, 10) : this.versionValue
  }

  reloadFrameOrPage() {
    const frame = document.getElementById(`gather_${this.gatherIdValue}_frame`)
    if (frame && typeof frame.reload === "function") {
      frame.reload()
      return
    }
    if (frame && frame.src) {
      frame.src = frame.src
      return
    }
    window.location.reload()
  }
}
