import { Controller } from "@hotwired/stimulus"

// User/profile handlers: profile tabs, browser timezone autofill, and Steam lookup.
// Mounted globally on <body>.
export default class extends Controller {
  connect() {
    this.fillBrowserTimeZone()
    this.handleTurboLoad = () => this.fillBrowserTimeZone()
    document.addEventListener("turbo:load", this.handleTurboLoad)
    document.addEventListener("turbo:render", this.handleTurboLoad)

    const $ = window.jQuery
    if (!$) return

    // Switches active tab styling and loads tab content via JS response.
    $(document).off("click.user", "#user-profile li a")
    $(document).on("click.user", "#user-profile li a", function() {
      const $userTabs = $("#user-profile .tabs")
      $userTabs.find("li").removeClass("activeli")
      $(this).parent().addClass("activeli")

      $.ajax({
        type: "GET",
        url: `${window.location.pathname}.js?page=${$(this).attr("id")}`,
        dataType: "script"
      })
    })

    // Replaces placeholder with fetched Steam profile link for the viewed user.
    $(document).off("click.user", "#steam-search a")
    $(document).on("click.user", "#steam-search a", function(event) {
      event.preventDefault()

      const $search = $("#steam-search")
      const id = $search.data("user-id")

      $search.html("<p>Searching...</p>")

      $.get(`/api/v1/users/${id}`, function(data) {
        $search.html(`<a href='${data.steam.url}'>Steam Profile: ${data.steam.nickname}</a>`)
      })
    })
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.handleTurboLoad)
    document.removeEventListener("turbo:render", this.handleTurboLoad)

    const $ = window.jQuery
    if (!$) return

    $(document).off("click.user", "#user-profile li a")
    $(document).off("click.user", "#steam-search a")
  }

  fillBrowserTimeZone() {
    const timeZoneInput = document.querySelector("[data-browser-time-zone]")
    if (timeZoneInput && !timeZoneInput.value && Intl.DateTimeFormat) {
      timeZoneInput.value = Intl.DateTimeFormat().resolvedOptions().timeZone || ""
    }
  }
}
