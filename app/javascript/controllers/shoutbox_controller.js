import { Controller } from "@hotwired/stimulus"

const REFLOW_EVENTS = ["turbo:load", "turbo:render", "turbo:frame-load"]

// Keeps shoutbox transcripts pinned to the bottom and supports wheel scrolling
// on the sidebar shoutbox widget. Mounted globally on <body>.
export default class extends Controller {
  connect() {
    this.initAutoscroll()

    this.handleReflow = () => this.initAutoscroll()
    this.handleStreamRender = () => setTimeout(() => this.initAutoscroll(), 0)
    REFLOW_EVENTS.forEach((eventName) => document.addEventListener(eventName, this.handleReflow))
    document.addEventListener("turbo:before-stream-render", this.handleStreamRender)

    this.handleWheel = (event) => {
      const transcript = event.target.closest("div#shoutbox")
      if (!transcript) return
      transcript.scrollTop += Math.round(event.deltaY)
    }
    document.addEventListener("wheel", this.handleWheel, { passive: true })
  }

  disconnect() {
    REFLOW_EVENTS.forEach((eventName) => document.removeEventListener(eventName, this.handleReflow))
    document.removeEventListener("turbo:before-stream-render", this.handleStreamRender)
    document.removeEventListener("wheel", this.handleWheel)
  }

  // Jump a shoutbox transcript to the newest message.
  scrollToBottom(el) {
    el.scrollTop = el.scrollHeight
  }

  // Keep every transcript pane pinned to the bottom and avoid double-binding observers.
  initAutoscroll() {
    document.querySelectorAll(".shoutbox-messages").forEach((el) => {
      this.scrollToBottom(el)

      if (el.dataset.shoutboxAutoscroll === "1") return
      el.dataset.shoutboxAutoscroll = "1"

      const observer = new MutationObserver(() => {
        setTimeout(() => this.scrollToBottom(el), 10)
      })
      observer.observe(el, { childList: true, subtree: true })
    })
  }
}

