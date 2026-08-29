import { Controller } from "@hotwired/stimulus"
import { postJSON, destroyJSON } from "lib/request"
import { showFlash } from "lib/flash"

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

  // Hide the button on browsers that can't do push at all, otherwise show the current state
  // and quietly make sure the server still holds a working subscription.
  connect() {
    if (!this.hasButtonTarget) return

    if (!this.supported()) {
      this.buttonTarget.hidden = true
      return
    }

    if (this.enabledValue) this.resync()

    this.updateButton()
  }

  // Browsers can rotate or drop a push subscription at any time, which would leave the stored
  // endpoint dead with no visible symptom. Re-posting the current one on every page load keeps
  // the database honest; re-registering also pulls in service worker updates.
  async resync() {
    try {
      const registration = await navigator.serviceWorker.register("/service-worker.js")
      await navigator.serviceWorker.ready

      const subscription = await registration.pushManager.getSubscription()
      if (!subscription) return

      await this.save(subscription)
    } catch (error) {
      console.warn("[ENSL push] could not refresh subscription", error)
    }
  }

  // Button click handler: switch the preference on or off, keeping the button locked while the
  // permission prompt and network round trip are in flight.
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
      showFlash(error.message || "Could not update push notifications.", "error")
    } finally {
      this.buttonTarget.disabled = false
      this.updateButton()
    }
  }

  // Ask for permission, subscribe this browser to the push service, and hand the subscription
  // to the server (which also sets the permanent profile preference).
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

    await this.save(subscription)
    this.enabledValue = true
    this.confirmDelivery(registration)
  }

  // Drop this browser's subscription and clear the server-side preference.
  async disable() {
    const registration = await navigator.serviceWorker.getRegistration("/service-worker.js")
    const subscription = registration ? await registration.pushManager.getSubscription() : null

    if (subscription) {
      await subscription.unsubscribe()
    }

    await destroyJSON(this.urlValue, { endpoint: subscription ? subscription.endpoint : "" })
    this.enabledValue = false
  }

  // Store this browser's subscription server-side, which also sets the profile preference.
  async save(subscription) {
    await postJSON(this.urlValue, { subscription: subscription.toJSON() })
  }

  // The browser grants permission happily even when the operating system is silently discarding
  // every notification, which looks to the user like the feature is simply broken. Fire one
  // notification straight away and tell them where to look if it never appears.
  confirmDelivery(registration) {
    registration
      .showNotification("Gather notifications enabled", {
        body: "You'll get a notification here when your gather starts.",
        tag: "ensl-optin",
        icon: "/images/shared/discord.png"
      })
      .catch(() => {})

    showFlash(
      `Notifications enabled. We just sent a test one - if nothing appeared, ${this.systemSettingsHint()}`,
      "notice"
    )
  }

  // Where to re-enable notifications for the browser itself, which is the setting people miss.
  systemSettingsHint() {
    const platform = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || ""

    if (/mac/i.test(platform)) {
      return "allow notifications for your browser in System Settings > Notifications."
    }
    if (/win/i.test(platform)) {
      return "allow notifications for your browser in Windows Settings > System > Notifications."
    }
    return "check that your system allows notifications from your browser."
  }

  // Push needs a service worker, a push service and a configured VAPID key; without all three
  // there is nothing to toggle.
  supported() {
    return (
      this.vapidPublicKeyValue.length > 0 &&
      "serviceWorker" in navigator &&
      "PushManager" in window &&
      typeof Notification !== "undefined"
    )
  }

  // Keep the label and pressed state in step with the stored preference.
  updateButton() {
    this.buttonTarget.textContent = this.enabledValue ? "Disable Notifications" : "Notify Me"
    this.buttonTarget.setAttribute("aria-pressed", this.enabledValue ? "true" : "false")
  }

  // The VAPID public key travels as base64url text but subscribe() wants raw bytes.
  decodeVapidKey(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw = window.atob(base64)
    return Uint8Array.from(raw, (char) => char.charCodeAt(0))
  }
}
