import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "loginButton"]
  static values = {
    optionsUrl: String,
    authenticateUrl: String,
    registerOptionsUrl: String,
    registerUrl: String
  }

  async connect() {
    if (!this.hasLoginButtonTarget) return

    const webauthn = await this.webauthn()
    if (!webauthn || !webauthn.browserSupportsWebAuthn()) return

    if (!(await this.supportsConditionalUI(webauthn))) return

    this.loginButtonTarget.style.display = "none"
    this.startConditionalLogin(webauthn)
  }

  async login(event) {
    event.preventDefault()

    const webauthn = await this.webauthn()
    if (!webauthn) return

    if (!webauthn.browserSupportsWebAuthn()) {
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
      const credential = await webauthn.startAuthentication({ optionsJSON: options })
      await this.finishLogin(credential)
    } catch (error) {
      this.showStatus(error.message || "Passkey authentication failed.")
    }
  }

  async startConditionalLogin(webauthn) {
    try {
      const options = await this.postJSON(this.optionsUrlValue, {})
      const credential = await webauthn.startAuthentication({
        optionsJSON: options,
        useBrowserAutofill: true,
        verifyBrowserAutofillInput: false
      })
      await this.finishLogin(credential)
    } catch (error) {
      if (error?.name === "AbortError" || error?.name === "NotAllowedError") return
      this.showStatus(error.message || "Passkey authentication failed.")
    }
  }

  async finishLogin(credential) {
    const result = await this.postJSON(this.authenticateUrlValue, { credential })

    if (result.redirect_to) {
      window.location.href = result.redirect_to
    } else {
      window.location.reload()
    }
  }

  async supportsConditionalUI(webauthn) {
    if (typeof webauthn.browserSupportsWebAuthnAutofill !== "function") return false

    try {
      return await webauthn.browserSupportsWebAuthnAutofill()
    } catch (_error) {
      return false
    }
  }

  async register(event) {
    event.preventDefault()

    const webauthn = await this.webauthn()
    if (!webauthn) return

    if (!webauthn.browserSupportsWebAuthn()) {
      this.showStatus("Passkeys are not supported in this browser.")
      return
    }

    try {
      const options = await this.postJSON(this.registerOptionsUrlValue, {})
      const credential = await webauthn.startRegistration({ optionsJSON: options })
      await this.postJSON(this.registerUrlValue, { credential })
      window.location.reload()
    } catch (error) {
      this.showStatus(error.message || "Passkey registration failed.")
    }
  }

  async webauthn() {
    if (this.webauthnLib) return this.webauthnLib

    try {
      this.webauthnLib = await import("@simplewebauthn/browser")
      return this.webauthnLib
    } catch (_error) {
      this.showStatus("Passkey library failed to load. Please refresh and try again.")
      return null
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
