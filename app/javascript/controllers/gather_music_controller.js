import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "muteButton"]
  static values = { shouldPlay: Boolean }

  // Set up the audio state, remember mute preference, and try autoplay if requested.
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

  // Remove the document click hook when the controller disconnects.
  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
  }

  // Stop the music when a vote link is clicked.
  handleDocumentClick(event) {
    if (event.target.closest(".vote-link")) this.stopOnVote()
  }

  // Flip mute state, store it, and refresh the button label.
  toggleMute() {
    if (!this.hasAudioTarget) return

    this.audioTarget.muted = !this.audioTarget.muted
    this.persistMutePreference(this.audioTarget.muted)
    this.updateMuteButton()
  }

  // Pause playback so vote actions do not keep the song running.
  stopOnVote() {
    if (!this.hasAudioTarget) return
    this.audioTarget.pause()
  }

  // Try to start playback, but leave the controls usable if autoplay is blocked.
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

  // Restore the saved mute choice from localStorage, or fall back to unmuted.
  applyStoredMutePreference() {
    try {
      this.audioTarget.muted = localStorage.getItem(this.mutedStorageKey) === "1"
    } catch (_error) {
      this.audioTarget.muted = false
    }
  }

  // Persist the user's mute choice so the next visit starts the same way.
  persistMutePreference(isMuted) {
    try {
      localStorage.setItem(this.mutedStorageKey, isMuted ? "1" : "0")
    } catch (_error) {
      // no-op
    }
  }

  // Keep the mute button label aligned with the current audio state.
  updateMuteButton() {
    if (!this.hasMuteButtonTarget || !this.hasAudioTarget) return

    this.muteButtonTarget.textContent = this.audioTarget.muted ? "Unmute" : "Mute"
  }
}
