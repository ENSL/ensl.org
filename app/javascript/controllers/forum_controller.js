import { Controller } from "@hotwired/stimulus"

// Forum handlers: quick-reply behavior in topic/post pages, and the generic
// data-on="click" / data-call dispatch used by inline "Quote" links.
// Mounted globally on <body>.
export default class extends Controller {
  connect() {
    const $ = window.jQuery
    if (!$) return

    // Shows the quick reply form and focuses its textarea, then hides the trigger button.
    $(document).off("click.forum", ".fastReply")
    $(document).on("click.forum", ".fastReply", function(e) {
      e.preventDefault()
      $("#reply").fadeIn("fast", function() {
        $(this).find("textarea").focus()
        $(".fastReply").addClass("invisible")
      })
    })

    $(document).off("click.forum", "[data-on='click'][data-call]")
    $(document).on("click.forum", "[data-on='click'][data-call]", (event) => this.dispatchDataCall(event))
  }

  disconnect() {
    const $ = window.jQuery
    if (!$) return

    $(document).off("click.forum", ".fastReply")
    $(document).off("click.forum", "[data-on='click'][data-call]")
  }

  // Looks up the requested handler by name and invokes it with the parsed args.
  dispatchDataCall(event) {
    const $ = window.jQuery
    const $el = $(event.currentTarget)
    const handlers = { QuoteText: (id, type) => this.quoteText(id, type) }
    const fn = handlers[$el.data("call")]
    if (!fn) return

    event.preventDefault()
    const args = String($el.data("args") || "")
      .split(",")
      .map((arg) => arg.trim().replace(/^['"]|['"]$/g, ""))
      .filter((arg) => arg.length > 0)

    fn(...args)
  }

  // Requests quote JS for a post/comment and executes the response.
  quoteText(id, type) {
    const $ = window.jQuery
    const quoteType = type || "posts"
    const url = quoteType === "posts" ? `/posts/${id}/quote.js` : `/${quoteType}/quote.js?id=${id}`

    $.ajax({
      type: "GET",
      url,
      dataType: "script"
    })
  }
}
