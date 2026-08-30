import { Controller } from "@hotwired/stimulus"

const MAX_LENGTH = 100

// Per-shoutbox input guard: warns and disables submission once the message is too long.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.messageBox = null
    this.updateInputState()
  }

  disconnect() {
    this.removeMessageBox()
  }

  updateInputState() {
    if (this.inputTarget.value.length > MAX_LENGTH) {
      this.disableShoutbox()
    } else {
      this.enableShoutbox()
    }
  }

  get submitButton() {
    return this.element.querySelector('input[type="submit"]')
  }

  writeMessage(message) {
    if (message === undefined) return this.removeMessageBox()
    this.createMessageBox().textContent = message
  }

  createMessageBox() {
    if (this.messageBox) return this.messageBox
    this.messageBox = document.createElement("p")
    this.messageBox.className = "shout-warning"
    this.element.querySelector(".fields")?.appendChild(this.messageBox)
    return this.messageBox
  }

  removeMessageBox() {
    if (this.messageBox) {
      this.messageBox.remove()
      this.messageBox = null
    }
  }

  disableShoutbox() {
    const chars = this.inputTarget.value.length
    this.writeMessage(`Maximum shout length exceeded (${chars}/100)`)
    this.submitButton?.setAttribute("disabled", "disabled")
  }

  enableShoutbox() {
    if (!this.submitButton?.hasAttribute("disabled")) {
      return
    }
    this.writeMessage()
    this.submitButton.removeAttribute("disabled")
  }
}
