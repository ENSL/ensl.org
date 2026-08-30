import { Controller } from "@hotwired/stimulus"

// User/profile handlers: profile tabs, browser timezone autofill, and Steam lookup.
// Mounted globally on <body>.
export default class extends Controller {
  connect() {
    this.fillBrowserTimeZone()
    this.handleTurboLoad = () => this.fillBrowserTimeZone()
    document.addEventListener("turbo:load", this.handleTurboLoad)
    document.addEventListener("turbo:render", this.handleTurboLoad)

    this.handleClick = (event) => {
      const tabLink = event.target.closest("#user-profile li a")
      if (tabLink) return this.switchTab(tabLink)

      const steamLink = event.target.closest("#steam-search a")
      if (steamLink) this.searchSteam(event)
    }
    document.addEventListener("click", this.handleClick)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.handleTurboLoad)
    document.removeEventListener("turbo:render", this.handleTurboLoad)
    document.removeEventListener("click", this.handleClick)
  }

  fillBrowserTimeZone() {
    const timeZoneInput = document.querySelector("[data-browser-time-zone]")
    if (timeZoneInput && !timeZoneInput.value && Intl.DateTimeFormat) {
      timeZoneInput.value = Intl.DateTimeFormat().resolvedOptions().timeZone || ""
    }
  }

  // Switches active tab styling and loads tab content via JS response.
  switchTab(tabLink) {
    const $ = window.jQuery
    if (!$) return

    document.querySelectorAll("#user-profile .tabs li").forEach((li) => li.classList.remove("activeli"))
    tabLink.parentElement?.classList.add("activeli")

    $.ajax({
      type: "GET",
      url: `${window.location.pathname}.js?page=${tabLink.id}`,
      dataType: "script"
    })
  }

  // Replaces placeholder with fetched Steam profile link for the viewed user.
  async searchSteam(event) {
    event.preventDefault()

    const container = document.getElementById("steam-search")
    if (!container) return

    const userId = container.dataset.userId
    container.innerHTML = "<p>Searching...</p>"

    const response = await fetch(`/api/v1/users/${userId}`)
    const data = await response.json()
    container.innerHTML = `<a href='${data.steam.url}'>Steam Profile: ${data.steam.nickname}</a>`
  }
}

