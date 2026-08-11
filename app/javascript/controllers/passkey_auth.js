import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loginButton"]
  static values = {
    optionsUrl: String,
    authenticateUrl: String,
    registerOptionsUrl: String,
    registerUrl: String,
    disableAutofill: Boolean
  }

  // The passkey button starts hidden (see the `hidden` attribute in the view) and is only
  // revealed once we know the browser can actually run a passkey ceremony, since there's no way
  // to ask in advance whether this site has a credential stored.
  async connect() {
    if (!this.hasLoginButtonTarget) return

    // Automated tests/browsers can't complete a real WebAuthn ceremony; keep the button visible
    // so it can still be exercised, without attempting background autofill.
    if (this.disableAutofillValue || navigator.webdriver) {
      this.loginButtonTarget.hidden = false
      return
    }

    const webauthn = await this.webauthn()
    const supported = !!webauthn && webauthn.browserSupportsWebAuthn() &&
      (await this.supportsConditionalUI(webauthn))

    this.loginButtonTarget.hidden = !supported
    if (!supported) return

    this.startConditionalLogin(webauthn)
  }

  // Run the explicit login flow after the user submits their username.
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

    // Cancel any background autofill ceremony from connect() before starting this one, so the
    // browser has the options round-trip below to actually release it (calling
    // startAuthentication() again would abort it too, but only right as the new request
    // starts, which isn't always enough lead time to avoid a "request already pending" error).
    webauthn.WebAuthnAbortService.cancelCeremony()

    try {
      const options = await this.postJSON(this.optionsUrlValue, { username })
      const credential = await webauthn.startAuthentication({ optionsJSON: options })
      await this.finishLogin(credential)
    } catch (error) {
      this.showStatus(this.describeAuthenticationError(error))
    }
  }

  // Try the browser autofill passkey flow without requiring a button click. Getting the
  // options or running the ceremony itself happens automatically on page load, so those
  // failures are only logged - the user never asked for this attempt. But once the user
  // has actually picked a credential from the browser's autofill dropdown and completed
  // it, a rejection from our server (e.g. the credential was since removed) is a direct
  // result of something they just did, so that failure is always shown.
  async startConditionalLogin(webauthn) {
    let credential

    try {
      const options = await this.postJSON(this.optionsUrlValue, {})
      credential = await webauthn.startAuthentication({
        optionsJSON: options,
        useBrowserAutofill: true,
        verifyBrowserAutofillInput: false
      })
    } catch (error) {
      if (error?.name === "AbortError" || error?.name === "NotAllowedError") return
      console.warn("Passkey autofill unavailable:", error)
      return
    }

    try {
      await this.finishLogin(credential)
    } catch (error) {
      this.showStatus(this.describeAuthenticationError(error))
    }
  }

  // Translate a failed navigator.credentials.get() call into a message worth showing.
  describeAuthenticationError(error) {
    if (error?.name === "NotAllowedError" && /pending/i.test(error.message || "")) {
      return "Still finishing a previous passkey request. Please try again."
    }

    return error?.message || "Passkey authentication failed."
  }

  // Send the signed credential to the server and follow any redirect it returns.
  async finishLogin(credential) {
    const result = await this.postJSON(this.authenticateUrlValue, { credential })

    if (result.redirect_to) {
      window.location.href = result.redirect_to
    } else {
      window.location.reload()
    }
  }

  // Check whether the browser exposes the conditional UI autofill helper.
  async supportsConditionalUI(webauthn) {
    if (typeof webauthn.browserSupportsWebAuthnAutofill !== "function") return false

    try {
      return await webauthn.browserSupportsWebAuthnAutofill()
    } catch (_error) {
      return false
    }
  }

  // Run the registration flow that creates a new passkey for the account.
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

  // Lazy-load the WebAuthn library and surface a readable error if it fails.
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

  // POST JSON with the Rails CSRF token and return the parsed response body.
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

  // Read the Rails CSRF token from the page head.
  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  // Show an error using the shared flash banner (like a failed password login) instead of a
  // local status box, so it doesn't squeeze the login fields when the message wraps.
  showStatus(text) {
    const notification = document.getElementById("notification")
    if (!notification) {
      window.alert(text)
      return
    }

    notification.innerHTML = ""
    const message = document.createElement("div")
    message.className = "message error"
    message.textContent = text
    notification.appendChild(message)
    notification.style.display = "block"
    notification.style.opacity = "1"

    this.scheduleFlashFade(notification)
  }

  // Mirror the same auto-fade behavior the server-rendered flash uses.
  scheduleFlashFade(notification) {
    if (document.body.dataset.disableFlashFade === "true") return

    window.clearTimeout(this.flashFadeTimeout)
    this.flashFadeTimeout = window.setTimeout(() => {
      if (window.jQuery) {
        window.jQuery(notification).fadeOut()
      } else {
        notification.style.display = "none"
      }
    }, 3000)
  }
}
