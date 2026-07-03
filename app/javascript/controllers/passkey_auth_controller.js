import { Controller } from "@hotwired/stimulus"
import {
  browserSupportsWebAuthn,
  startAuthentication,
  startRegistration
} from "@simplewebauthn/browser"

export default class extends Controller {
  static targets = ["status"]
  static values = {
    optionsUrl: String,
    authenticateUrl: String,
    registerOptionsUrl: String,
    registerUrl: String
  }

  async login(event) {
    event.preventDefault()

    if (!browserSupportsWebAuthn()) {
      this.showStatus("Passkeys are not supported in this browser.")
      return
    }

    const usernameInput = this.element.querySelector("input[name='login[username]']")
    const username = usernameInput ? usernameInput.value.trim() : ""

    if (username.length === 0) {
      this.showStatus("Enter your username before using a passkey.")
      return
    }

    try {
      const options = await this.postJSON(this.optionsUrlValue, { username })
      const credential = await startAuthentication({ optionsJSON: options })
      const result = await this.postJSON(this.authenticateUrlValue, { credential })

      if (result.redirect_to) {
        window.location.href = result.redirect_to
      } else {
        window.location.reload()
      }
    } catch (error) {
      this.showStatus(error.message || "Passkey authentication failed.")
    }
  }

  async register(event) {
    event.preventDefault()

    if (!browserSupportsWebAuthn()) {
      this.showStatus("Passkeys are not supported in this browser.")
      return
    }

    try {
      const options = await this.postJSON(this.registerOptionsUrlValue, {})
      const credential = await startRegistration({ optionsJSON: options })
      await this.postJSON(this.registerUrlValue, { credential })
      window.location.reload()
    } catch (error) {
      this.showStatus(error.message || "Passkey registration failed.")
    }
  }

  async postJSON(url, payload) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: JSON.stringify(payload)
    })

    const json = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(json.error || "Request failed")
    }

    return json
  }

  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  showStatus(text) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
      return
    }

    window.alert(text)
  }
}
