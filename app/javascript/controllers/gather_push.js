import { Controller } from "@hotwired/stimulus"

// Toggles browser push notifications for gathers. Enabling asks for notification permission,
// registers the service worker and stores the resulting subscription server-side, which also
// flips the permanent `notify_push_gather` profile preference.
export default class extends Controller {
  static targets = ["button"]
  static values = {
    vapidPublicKey: String,
    url: String,
    enabled: Boolean
  }

  connect() {
    if (!this.hasButtonTarget) return

    if (!this.supported()) {
      this.buttonTarget.hidden = true
      return
    }

    if (this.enabledValue) this.resync()

    this.updateButton()
  }

  // Browsers can rotate or drop a push subscription at any time, which would leave the
  // stored endpoint dead. Re-registering also picks up service worker updates.
  async resync() {
    try {
      const registration = await navigator.serviceWorker.register("/service-worker.js")
      await navigator.serviceWorker.ready

      const subscription = await registration.pushManager.getSubscription()
      if (!subscription) return

      await this.postJSON(this.urlValue, "POST", { subscription: subscription.toJSON() })
    } catch (error) {
      console.warn("[ENSL push] could not refresh subscription", error)
    }
  }

  async toggle() {
    if (!this.supported()) return

    this.buttonTarget.disabled = true
    try {
      if (this.enabledValue) {
        await this.disable()
      } else {
        await this.enable()
      }
    } catch (error) {
      this.showError(error.message || "Could not update push notifications.")
    } finally {
      this.buttonTarget.disabled = false
      this.updateButton()
    }
  }

  async enable() {
    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      throw new Error("Notifications are blocked for this site in your browser settings.")
    }

    const registration = await navigator.serviceWorker.register("/service-worker.js")
    await navigator.serviceWorker.ready

    const subscription =
      (await registration.pushManager.getSubscription()) ||
      (await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.decodeVapidKey(this.vapidPublicKeyValue)
      }))

    await this.postJSON(this.urlValue, "POST", { subscription: subscription.toJSON() })
    this.enabledValue = true
  }

  async disable() {
    const registration = await navigator.serviceWorker.getRegistration("/service-worker.js")
    const subscription = registration ? await registration.pushManager.getSubscription() : null

    if (subscription) {
      await subscription.unsubscribe()
    }

    await this.postJSON(this.urlValue, "DELETE", { endpoint: subscription ? subscription.endpoint : "" })
    this.enabledValue = false
  }

  supported() {
    return (
      this.vapidPublicKeyValue.length > 0 &&
      "serviceWorker" in navigator &&
      "PushManager" in window &&
      typeof Notification !== "undefined"
    )
  }

  updateButton() {
    this.buttonTarget.textContent = this.enabledValue ? "Disable Notifications" : "Notify Me"
    this.buttonTarget.setAttribute("aria-pressed", this.enabledValue ? "true" : "false")
  }

  async postJSON(url, method, payload) {
    const response = await fetch(url, {
      method: method,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: JSON.stringify(payload)
    })

    const json = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(json.error || "Request failed")

    return json
  }

  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  showError(text) {
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
  }

  // The VAPID public key travels as base64url text but subscribe() wants raw bytes.
  decodeVapidKey(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw = window.atob(base64)
    return Uint8Array.from(raw, (char) => char.charCodeAt(0))
  }
}
