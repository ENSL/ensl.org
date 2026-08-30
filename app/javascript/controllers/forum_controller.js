import { Controller } from "@hotwired/stimulus"

// Forum handlers: quick-reply behavior in topic/post pages, and the generic
// data-on="click" / data-call dispatch used by inline "Quote" links.
// Mounted globally on <body>.
export default class extends Controller {
  connect() {
    this.handleClick = (event) => {
      if (event.target.closest(".fastReply")) return this.showReply(event)

      const callTarget = event.target.closest("[data-on='click'][data-call]")
      if (callTarget) this.dispatchDataCall(event, callTarget)
    }

    document.addEventListener("click", this.handleClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClick)
  }

  // Shows the quick reply form and focuses its textarea, then hides the trigger button.
  showReply(event) {
    event.preventDefault()
    const $ = window.jQuery
    if (!$) return

    $("#reply").fadeIn("fast", function() {
      $(this).find("textarea").focus()
      document.querySelectorAll(".fastReply").forEach((button) => button.classList.add("invisible"))
    })
  }

  // Looks up the requested handler by name and invokes it with the parsed args.
  dispatchDataCall(event, el) {
    const handlers = { QuoteText: (id, type) => this.quoteText(id, type) }
    const fn = handlers[el.dataset.call]
    if (!fn) return

    event.preventDefault()
    const args = String(el.dataset.args || "")
      .split(",")
      .map((arg) => arg.trim().replace(/^['"]|['"]$/g, ""))
      .filter((arg) => arg.length > 0)

    fn(...args)
  }

  // Requests quote JS for a post/comment and executes the response.
  quoteText(id, type) {
    const $ = window.jQuery
    if (!$) return

    const quoteType = type || "posts"
    const url = quoteType === "posts" ? `/posts/${id}/quote.js` : `/${quoteType}/quote.js?id=${id}`

    $.ajax({
      type: "GET",
      url,
      dataType: "script"
    })
  }
}

