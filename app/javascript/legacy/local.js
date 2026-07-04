import { bindForumHandlers, QuoteText } from "legacy/forum"
import { bindUserHandlers, findUser, HideUserPopup, ShowUserPopup } from "legacy/user"
import { add_fields, bindFormHandlers, remove_fields } from "legacy/forms"

// Binds delegated jQuery handlers for legacy UI widgets across Turbo page changes.
function bindLocalHandlers() {
  bindForumHandlers()
  bindUserHandlers()
  bindFormHandlers()

  // Dismisses the gather-info panel from the gather page.
  $(document).off("click", "a#gather-info-hide")
  $(document).on("click", "a#gather-info-hide", function() {
    $("div#gather-info").fadeOut("slow", 0)
  })

  // Updates match proposal status from clicked action and patches row cells from JSON response.
  $(document).off("click", "form.edit_match_proposal a")
  $(document).on("click", "form.edit_match_proposal a", function() {
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

  if (!(document.body && document.body.dataset && document.body.dataset.disableFlashFade === "true")) {
    // Fades transient flash notification after a short delay unless explicitly disabled.
    $("#notification").delay(3000).fadeOut()
  }
}

window.ShowUserPopup = ShowUserPopup
window.HideUserPopup = HideUserPopup
window.bindLocalHandlers = bindLocalHandlers
window.findUser = findUser
window.QuoteText = QuoteText
window.remove_fields = remove_fields
window.add_fields = add_fields

// Rebind the legacy handlers on initial load and on Turbo navigation events.
document.addEventListener("DOMContentLoaded", bindLocalHandlers)
document.addEventListener("turbo:load", bindLocalHandlers)
document.addEventListener("turbo:render", bindLocalHandlers)
