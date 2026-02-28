import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "muteButton"]
  static values = { shouldPlay: Boolean }

  connect() {
    if (!this.hasAudioTarget) return

    this.mutedStorageKey = "gather_music_muted"
    this.onDocumentClick = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.onDocumentClick)

    this.applyStoredMutePreference()
    this.updateMuteButton()

    if (this.shouldPlayValue) {
      this.tryAutoplay()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
  }

  handleDocumentClick(event) {
    if (event.target.closest(".vote-link")) this.stopOnVote()
  }

  toggleMute() {
    if (!this.hasAudioTarget) return

    this.audioTarget.muted = !this.audioTarget.muted
    this.persistMutePreference(this.audioTarget.muted)
    this.updateMuteButton()
  }

  stopOnVote() {
    if (!this.hasAudioTarget) return
    this.audioTarget.pause()
  }

  tryAutoplay() {
    if (!this.hasAudioTarget) return

    this.audioTarget.dataset.autoplayAttempted = "1"

    if (this.audioTarget.muted) return

    const playPromise = this.audioTarget.play()
    if (playPromise && typeof playPromise.catch === "function") {
      playPromise.catch(() => {
        // Browser autoplay policy may block this; controls remain available.
      })
    }
  }

  applyStoredMutePreference() {
    try {
      this.audioTarget.muted = localStorage.getItem(this.mutedStorageKey) === "1"
    } catch (_error) {
      this.audioTarget.muted = false
    }
  }

  persistMutePreference(isMuted) {
    try {
      localStorage.setItem(this.mutedStorageKey, isMuted ? "1" : "0")
    } catch (_error) {
      // no-op
    }
  }

  updateMuteButton() {
    if (!this.hasMuteButtonTarget || !this.hasAudioTarget) return

    this.muteButtonTarget.textContent = this.audioTarget.muted ? "Unmute" : "Mute"
  }
}
