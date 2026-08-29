// Service worker for ENSL web push notifications.
// Registered from the gather page (see app/javascript/controllers/gather_push.js) and served
// from /service-worker.js so it can claim the whole site as its scope.

self.addEventListener("install", () => self.skipWaiting())
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()))

self.addEventListener("push", (event) => {
  let payload = {}
  try {
    payload = event.data ? event.data.json() : {}
  } catch (_error) {
    payload = { body: event.data ? event.data.text() : "" }
  }

  const title = payload.title || "ENSL"
  const options = {
    body: payload.body || "",
    tag: payload.tag || "ensl",
    icon: "/images/shared/favicon.ico",
    renotify: true,
    data: { url: payload.url || "/" }
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const target = new URL((event.notification.data && event.notification.data.url) || "/", self.location.origin).href

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url === target && "focus" in client) return client.focus()
      }
      return self.clients.openWindow ? self.clients.openWindow(target) : undefined
    })
  )
})
