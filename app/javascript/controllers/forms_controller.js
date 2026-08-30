import { Controller } from "@hotwired/stimulus"

// Generic form handlers: link-driven form submission, select decoration, autosubmit selects,
// and nested-form "add fields" support. Mounted globally on <body>; binds via delegation since
// the markup it targets (data-submit-form links, autosubmit selects, plain selects) is rendered
// across many unrelated views/partials.
export default class extends Controller {
  connect() {
    const $ = window.jQuery
    if (!$) return

    // Emulates rails-ujs link-to-form-submit with optional confirm and dynamic action override.
    $(document).off("click.forms", "a[data-submit-form]")
    $(document).on("click.forms", "a[data-submit-form]", (event) => this.submitForm(event))

    // Auto-submits forms when autosubmit select values change.
    $(document).off("change.forms", "select.autosubmit")
    $(document).on("change.forms", "select.autosubmit", function() {
      $(this).closest("form").submit()
    })

    this.wrapSelects()
    this.handleReflow = () => this.wrapSelects()
    document.addEventListener("turbo:load", this.handleReflow)
    document.addEventListener("turbo:render", this.handleReflow)
    document.addEventListener("turbo:frame-load", this.handleReflow)
  }

  disconnect() {
    const $ = window.jQuery
    if ($) {
      $(document).off("click.forms", "a[data-submit-form]")
      $(document).off("change.forms", "select.autosubmit")
    }

    document.removeEventListener("turbo:load", this.handleReflow)
    document.removeEventListener("turbo:render", this.handleReflow)
    document.removeEventListener("turbo:frame-load", this.handleReflow)
  }

  submitForm(event) {
    event.preventDefault()
    const $ = window.jQuery
    const $link = $(event.currentTarget)

    const confirmMessage = $link.data("confirm")
    if (confirmMessage && !window.confirm(confirmMessage)) {
      return
    }

    const formId = $link.data("form-id")
    const formSelector = $link.data("form-selector")
    let form = null

    if (formId) {
      form = document.getElementById(formId)
    } else if (formSelector) {
      form = document.querySelector(formSelector)
    } else {
      form = $link.closest("form")[0]
    }

    const url = $link.data("url") || $link.data("form-action")
    if (form && url) {
      try { form.action = url } catch (_err) { }
    }

    if (form) {
      this.refreshFormAuthenticityToken(form)
      form.submit()
    }
  }

  // Refresh the hidden authenticity token so legacy form submissions still pass CSRF checks.
  refreshFormAuthenticityToken(form) {
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

  // Wraps plain selects once, then mirrors disabled state to wrapper class for styling hooks.
  wrapSelects() {
    const $ = window.jQuery
    if (!$) return

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
  }

  // Rails nested-form helper: inserts association template with a unique placeholder ID.
  // data-action="click->forms#addFields"
  addFields(event) {
    event.preventDefault()
    const { association, template } = event.params
    const newId = Date.now()
    const regexp = new RegExp(`new_${association}`, "g")
    event.currentTarget.parentElement.insertAdjacentHTML("beforebegin", template.replace(regexp, newId))
  }
}
