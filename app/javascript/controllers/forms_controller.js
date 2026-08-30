import { Controller } from "@hotwired/stimulus"

const REFLOW_EVENTS = ["turbo:load", "turbo:render", "turbo:frame-load"]

// Generic form handlers: link-driven form submission, select decoration, autosubmit selects,
// and nested-form "add fields" support. Mounted globally on <body>; binds via delegation since
// the markup it targets (data-submit-form links, autosubmit selects, plain selects) is rendered
// across many unrelated views/partials.
export default class extends Controller {
  connect() {
    // Emulates rails-ujs link-to-form-submit with optional confirm and dynamic action override.
    this.handleClick = (event) => {
      const link = event.target.closest("a[data-submit-form]")
      if (link) this.submitForm(event, link)
    }

    // Auto-submits forms when autosubmit select values change.
    this.handleChange = (event) => {
      const select = event.target.closest("select.autosubmit")
      if (select) select.closest("form")?.submit()
    }

    document.addEventListener("click", this.handleClick)
    document.addEventListener("change", this.handleChange)

    this.wrapSelects()
    this.handleReflow = () => this.wrapSelects()
    REFLOW_EVENTS.forEach((eventName) => document.addEventListener(eventName, this.handleReflow))
  }

  disconnect() {
    document.removeEventListener("click", this.handleClick)
    document.removeEventListener("change", this.handleChange)
    REFLOW_EVENTS.forEach((eventName) => document.removeEventListener(eventName, this.handleReflow))
  }

  submitForm(event, link) {
    event.preventDefault()

    const confirmMessage = link.dataset.confirm
    if (confirmMessage && !window.confirm(confirmMessage)) {
      return
    }

    const { formId, formSelector, url, formAction } = link.dataset
    let form = null

    if (formId) {
      form = document.getElementById(formId)
    } else if (formSelector) {
      form = document.querySelector(formSelector)
    } else {
      form = link.closest("form")
    }

    const targetUrl = url || formAction
    if (form && targetUrl) {
      try { form.action = targetUrl } catch (_err) { }
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
    document.querySelectorAll("select").forEach((select) => {
      if (select.parentElement?.classList.contains("select-wrapper")) return

      const wrapper = document.createElement("div")
      wrapper.className = "select-wrapper"
      select.replaceWith(wrapper)
      wrapper.appendChild(select)

      this.syncSelectWrapperState(select)
      new MutationObserver(() => this.syncSelectWrapperState(select))
        .observe(select, { attributes: true, attributeFilter: ["disabled"] })
    })
  }

  syncSelectWrapperState(select) {
    select.parentElement?.classList.toggle("disabled", select.disabled)
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
