// Forum handlers: quick-reply behavior in topic/post pages.
export function bindForumHandlers() {
  // Shows the quick reply form and focuses its textarea, then hides the trigger button.
  $(document).off("click", ".fastReply")
  $(document).on("click", ".fastReply", function(e) {
    e.preventDefault()
    $("#reply").fadeIn("fast", function() {
      $(this).find("textarea").focus()
      $(".fastReply").addClass("invisible")
    })
  })

  $(document).off("click", "[data-on='click'][data-call]")
  $(document).on("click", "[data-on='click'][data-call]", function(e) {
    const fn = window[$(this).data("call")]
    if (typeof fn !== "function") return

    e.preventDefault()
    const args = String($(this).data("args") || "")
      .split(",")
      .map((arg) => arg.trim().replace(/^['\"]|['\"]$/g, ""))
      .filter((arg) => arg.length > 0)

    fn(...args)
  })
}

// Legacy global helper: requests quote JS for a post/comment and executes response.
export function QuoteText(id, type) {
  const quoteType = type || "posts"
  const url = quoteType === "posts" ? `/posts/${id}/quote.js` : `/${quoteType}/quote.js?id=${id}`

  $.ajax({
    type: "GET",
    url,
    dataType: "script"
  })
}
