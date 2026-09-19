import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { gatherId: Number }

  connect() {
    const selectedPlayerId = sessionStorage.getItem(this.storageKey)
    if (!selectedPlayerId) return

    const input = this.element.querySelector(`input[name="player"][value="${selectedPlayerId}"]`)
    if (input) {
      input.checked = true
    } else {
      this.clearSelection()
    }
  }

  rememberSelection(event) {
    if (event.target.matches('input[name="player"]') && event.target.checked) {
      sessionStorage.setItem(this.storageKey, event.target.value)
    }
  }

  clearSelection() {
    sessionStorage.removeItem(this.storageKey)
  }

  get storageKey() {
    return `gather-pick:${this.gatherIdValue}`
  }
}