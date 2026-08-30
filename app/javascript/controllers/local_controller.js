import { Controller } from "@hotwired/stimulus"

// Miscellaneous page glue: dismissing the gather-info panel, updating match proposal
// status from inline action links, and fading the server-rendered flash notification.
// Mounted globally on <body>.
export default class extends Controller {
  connect() {
    this.fadeFlash()
    this.handleTurboLoad = () => this.fadeFlash()
    document.addEventListener("turbo:load", this.handleTurboLoad)
    document.addEventListener("turbo:render", this.handleTurboLoad)

    const $ = window.jQuery
    if (!$) return

    // Dismisses the gather-info panel from the gather page.
    $(document).off("click.local", "a#gather-info-hide")
    $(document).on("click.local", "a#gather-info-hide", function() {
      $("div#gather-info").fadeOut("slow", 0)
    })

    // Updates match proposal status from clicked action and patches row cells from JSON response.
    $(document).off("click.local", "form.edit_match_proposal a")
    $(document).on("click.local", "form.edit_match_proposal a", function() {
      const form = $(this).closest("form.edit_match_proposal")
      form.children("input#match_proposal_status").val($(this).data("id"))
      $.post(form.attr("action"), form.serialize(), function(data) {
        const tr = form.closest("tr")
        tr.children("td").eq(2).text(data.status)
        if (data.status === "Revoked" || data.status === "Rejected") tr.children("td").eq(3).empty()
      }, "json")
        .fail(function(err) {
          const errjson = JSON.parse(err.responseText)
          alert(errjson.error.message)
        })
    })
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.handleTurboLoad)
    document.removeEventListener("turbo:render", this.handleTurboLoad)

    const $ = window.jQuery
    if (!$) return

    $(document).off("click.local", "a#gather-info-hide")
    $(document).off("click.local", "form.edit_match_proposal a")
  }

  // Fades transient flash notification after a short delay unless explicitly disabled.
  fadeFlash() {
    const $ = window.jQuery
    if (!$) return
    if (document.body?.dataset?.disableFlashFade === "true") return

    $("#notification").delay(3000).fadeOut()
  }
}
