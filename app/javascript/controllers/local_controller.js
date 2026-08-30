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

    this.handleClick = (event) => {
      if (event.target.closest("a#gather-info-hide")) return this.hideGatherInfo()

      const proposalLink = event.target.closest("form.edit_match_proposal a")
      if (proposalLink) this.updateMatchProposal(proposalLink)
    }
    document.addEventListener("click", this.handleClick)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.handleTurboLoad)
    document.removeEventListener("turbo:render", this.handleTurboLoad)
    document.removeEventListener("click", this.handleClick)
  }

  // Dismisses the gather-info panel from the gather page.
  hideGatherInfo() {
    const $ = window.jQuery
    if (!$) return
    $("div#gather-info").fadeOut("slow", 0)
  }

  // Updates match proposal status from clicked action and patches row cells from JSON response.
  updateMatchProposal(link) {
    const $ = window.jQuery
    if (!$) return

    const form = $(link).closest("form.edit_match_proposal")
    form.children("input#match_proposal_status").val($(link).data("id"))
    $.post(form.attr("action"), form.serialize(), function(data) {
      const tr = form.closest("tr")
      tr.children("td").eq(2).text(data.status)
      if (data.status === "Revoked" || data.status === "Rejected") tr.children("td").eq(3).empty()
    }, "json")
      .fail(function(err) {
        const errjson = JSON.parse(err.responseText)
        alert(errjson.error.message)
      })
  }

  // Fades transient flash notification after a short delay unless explicitly disabled.
  fadeFlash() {
    const $ = window.jQuery
    if (!$) return
    if (document.body?.dataset?.disableFlashFade === "true") return

    $("#notification").delay(3000).fadeOut()
  }
}

