// Shared flash banner rendering for Stimulus controllers, mirroring the server-rendered
// `application/_messages` markup and its auto-fade so client-side messages look identical.
let fadeTimeout

export function showFlash(text, kind = "notice") {
  const notification = document.getElementById("notification")
  if (!notification) {
    window.alert(text)
    return
  }

  notification.innerHTML = ""
  const message = document.createElement("div")
  message.className = `message ${kind}`
  message.textContent = text
  notification.appendChild(message)
  notification.style.display = "block"
  notification.style.opacity = "1"

  scheduleFade(notification)
}

function scheduleFade(notification) {
  if (document.body.dataset.disableFlashFade === "true") return

  window.clearTimeout(fadeTimeout)
  fadeTimeout = window.setTimeout(() => {
    if (window.jQuery) {
      window.jQuery(notification).fadeOut()
    } else {
      notification.style.display = "none"
    }
  }, 3000)
}
