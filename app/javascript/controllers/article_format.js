import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "form", "select"]
  static values = { html: Number }

  connect() {
    if (!this.hasSelectTarget || this.hasFormTarget) return

    const textarea = this.editorTarget.querySelector("textarea")
    if (textarea?.value.trim()) this.contentChanged()
  }

  newFormatChanged() {
    if (this.selectTarget.disabled) return

    const enabled = Number(this.selectTarget.value) === this.htmlValue
    this.editorTarget.dataset.articleEditorEnabledValue = enabled
  }

  convert() {
    if (!this.selectTarget.value) return

    const confirmed = window.confirm(
      "Converting this article format is irreversible. Are you sure you want to continue?"
    )

    if (confirmed) {
      this.formTarget.requestSubmit()
    } else {
      this.selectTarget.value = ""
    }
  }

  contentChanged() {
    if (!this.hasSelectTarget) return

    if (this.hasFormTarget) {
      this.selectTarget.value = ""
    } else {
      this.preserveNewArticleFormat()
    }
    this.selectTarget.disabled = true
    this.selectTarget.title = this.hasFormTarget
      ? "Save content changes before converting the format."
      : "The format is locked after content editing begins."
  }

  preserveNewArticleFormat() {
    if (this.element.querySelector("input[data-article-format-preserved]")) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = this.selectTarget.name
    hidden.value = this.selectTarget.value
    hidden.dataset.articleFormatPreserved = "true"
    this.selectTarget.form.append(hidden)
  }
}