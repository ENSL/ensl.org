import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, title: String, image: Boolean }

  connect() {
    window.dispatchEvent(new CustomEvent("article:file-added", {
      detail: { url: this.urlValue, title: this.titleValue, image: this.imageValue }
    }))
    this.element.remove()
  }
}