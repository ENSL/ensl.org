import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Parse the current page and future DOM additions for emoji images.
  connect() {
    this.parseNode(document.body)

    this.handleTurboLoad = () => this.parseNode(document.body)
    this.handleAjaxComplete = () => this.parseNode(document.body)

    document.addEventListener("turbo:load", this.handleTurboLoad)

    if (window.jQuery) {
      window.jQuery(document).on("ajaxComplete", this.handleAjaxComplete)
    }

    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            this.parseNode(node)
          }
        })
      })
    })

    if (document.body) {
      this.observer.observe(document.body, { childList: true, subtree: true })
    }
  }

  // Clean up the listeners and mutation observer on disconnect.
  disconnect() {
    document.removeEventListener("turbo:load", this.handleTurboLoad)

    if (window.jQuery) {
      window.jQuery(document).off("ajaxComplete", this.handleAjaxComplete)
    }

    if (this.observer) {
      this.observer.disconnect()
    }
  }

  // Replace text emoji with Twemoji SVG markup inside the given node.
  parseNode(node) {
    if (typeof twemoji === "undefined" || !node) {
      return
    }

    twemoji.parse(node, {
      folder: "svg",
      ext: ".svg"
    })
  }
}
