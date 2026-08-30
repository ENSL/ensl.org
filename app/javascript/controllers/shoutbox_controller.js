import { Controller } from "@hotwired/stimulus"

// Keeps shoutbox transcripts pinned to the bottom and supports mousewheel scrolling
// on the sidebar shoutbox widget. Mounted globally on <body>.
export default class extends Controller {
  connect() {
    this.initAutoscroll()

    this.handleReflow = () => this.initAutoscroll()
    this.handleStreamRender = () => setTimeout(() => this.initAutoscroll(), 0)
    ;["turbo:load", "turbo:render", "turbo:frame-load"].forEach((eventName) => {
      document.addEventListener(eventName, this.handleReflow)
    })
    document.addEventListener("turbo:before-stream-render", this.handleStreamRender)

    const $ = window.jQuery
    if (!$) return

    $(document).off("mousewheel.shoutbox", "div#shoutbox")
    $(document).on("mousewheel.shoutbox", "div#shoutbox", function(ev, delta) {
      const scrollTop = $(this).scrollTop()
      $(this).scrollTop(scrollTop - Math.round(delta))
    })
  }

  disconnect() {
    ;["turbo:load", "turbo:render", "turbo:frame-load"].forEach((eventName) => {
      document.removeEventListener(eventName, this.handleReflow)
    })
    document.removeEventListener("turbo:before-stream-render", this.handleStreamRender)

    const $ = window.jQuery
    if (!$) return
    $(document).off("mousewheel.shoutbox", "div#shoutbox")
  }

  // Jump a shoutbox transcript to the newest message.
  scrollToBottom(el) {
    el.scrollTop = el.scrollHeight
  }

  // Keep every transcript pane pinned to the bottom and avoid double-binding observers.
  initAutoscroll() {
    const $ = window.jQuery
    if (!$) return

    $(".shoutbox-messages").each((_i, el) => {
      this.scrollToBottom(el)

      if (el.dataset && el.dataset.shoutboxAutoscroll === "1") {
        return
      }
      if (el.dataset) {
        el.dataset.shoutboxAutoscroll = "1"
      }

      const observer = new MutationObserver(() => {
        setTimeout(() => this.scrollToBottom(el), 10)
      })
      observer.observe(el, { childList: true, subtree: true })
    })
  }
}
