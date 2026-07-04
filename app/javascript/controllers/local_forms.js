// Refresh the hidden authenticity token so legacy form submissions still pass CSRF checks.
function refreshFormAuthenticityToken(form) {
  if (!form) return

  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  const csrfParam = document.querySelector("meta[name='csrf-param']")?.getAttribute("content") || "authenticity_token"
  if (!csrfToken) return

  let tokenInput = form.querySelector(`input[name='${csrfParam}']`)
  if (!tokenInput) {
    tokenInput = document.createElement("input")
    tokenInput.type = "hidden"
    tokenInput.name = csrfParam
    form.appendChild(tokenInput)
  }

  tokenInput.value = csrfToken
}

// Generic form handlers: link-driven form submission, select decoration, and autosubmit selects.
export function bindFormHandlers() {
  // Emulates rails-ujs link-to-form-submit with optional confirm and dynamic action override.
  $(document).off("click", "a[data-submit-form]")
  $(document).on("click", "a[data-submit-form]", function(e) {
    e.preventDefault()
    const confirmMessage = $(this).data("confirm")
    if (confirmMessage && !window.confirm(confirmMessage)) {
      return
    }
    const formId = $(this).data("form-id")
    const formSelector = $(this).data("form-selector")
    let form = null

    if (formId) {
      form = document.getElementById(formId)
    } else if (formSelector) {
      form = document.querySelector(formSelector)
    } else {
      form = $(this).closest("form")[0]
    }

    const url = $(this).data("url") || $(this).data("form-action")
    if (form && url) {
      try { form.action = url } catch (_err) { }
    }

    if (form) {
      refreshFormAuthenticityToken(form)
      form.submit()
    }
  })

  // Wraps plain selects once, then mirrors disabled state to wrapper class for styling hooks.
  $("select").each(function(_i, el) {
    const $select = $(el)
    if ($select.parent().hasClass("select-wrapper")) return

    $select.wrap('<div class="select-wrapper" />')
    $select.off("DOMSubtreeModified")
    $select.on("DOMSubtreeModified", function() {
      const $el = $(this)
      const $wrapper = $el.parent()
      $wrapper.toggleClass("disabled", $el.is("[disabled]"))
    })

    $select.trigger("DOMSubtreeModified")
  })

  // Auto-submits forms when autosubmit select values change.
  $(document).off("change", "select.autosubmit")
  $(document).on("change", "select.autosubmit", function() {
    $(this).closest("form").submit()
  })
}

// Rails nested-form helper: marks row for destroy and hides the linked field block.
export function remove_fields(link) {
  $(link).prev("input[type=hidden]").val("1")
  $(link).closest(".fields").hide()
}

// Rails nested-form helper: inserts association template with a unique placeholder ID.
export function add_fields(link, association, content) {
  const newId = Date.now()
  const regexp = new RegExp(`new_${association}`, "g")
  $(link).parent().before(content.replace(regexp, newId))
}
