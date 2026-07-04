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
}

// Legacy global helper: requests quote JS for a post/comment and executes response.
export function QuoteText(id, type) {
  const quoteType = type || "posts"
  $.ajax({
    type: "GET",
    url: `/${quoteType}/quote/${id}.js`,
    dataType: "script"
  })
}
