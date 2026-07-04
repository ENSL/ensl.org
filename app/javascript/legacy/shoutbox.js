// Jump a shoutbox transcript to the newest message.
function scrollToBottom(el) {
  el.scrollTop = el.scrollHeight
}

// Keep every transcript pane pinned to the bottom and avoid double-binding observers.
function initShoutboxAutoscroll() {
  const $transcripts = $(".shoutbox-messages")
  $transcripts.each(function() {
    const el = this
    scrollToBottom(el)

    if (el.dataset && el.dataset.shoutboxAutoscroll === "1") {
      return
    }
    if (el.dataset) {
      el.dataset.shoutboxAutoscroll = "1"
    }

    const observer = new MutationObserver(function() {
      setTimeout(function() { scrollToBottom(el) }, 10)
    })
    observer.observe(el, { childList: true, subtree: true })
  })
}

// Wire the scroll, submit, and post-submit behaviors for the shout form.
function bindShoutboxHandlers() {
  $(document).off("mousewheel", "div#shoutbox")
  $(document).on("mousewheel", "div#shoutbox", function(ev, delta) {
    const scrollTop = $(this).scrollTop()
    $(this).scrollTop(scrollTop - Math.round(delta))
  })

  $(document).off("submit", "form.new_shoutmsg")
  $(document).on("submit", "form.new_shoutmsg", function() {
    $("input[type=submit]", this).attr("disabled", "disabled")
  })

  $(document).off("ajax:complete", "form.new_shoutmsg")
  $(document).on("ajax:complete", "form.new_shoutmsg", function() {
    const self = this
    $(this)[0].reset()
    setTimeout(function() {
      $("input[type=submit]", self).removeAttr("disabled")
    }, 2000)
  })
}

// Re-run shoutbox setup on page loads and Turbo navigation events.
["DOMContentLoaded", "turbo:load", "turbo:render", "turbo:frame-load"].forEach(function(eventName) {
  document.addEventListener(eventName, initShoutboxAutoscroll)
  document.addEventListener(eventName, bindShoutboxHandlers)
})

// Reinitialize autoscroll after Turbo streams insert new shout content.
document.addEventListener("turbo:before-stream-render", function() {
  setTimeout(initShoutboxAutoscroll, 0)
})

// Lightweight controller wrapper that manages shoutbox input state and messaging.
function ShoutboxController(options) {
  if (!(this instanceof ShoutboxController)) {
    return new ShoutboxController(options)
  }
  this.options = options || {}
  this.$context = this.options.context || $()

  if (!this.$context.length) {
    console.log("Unable to initialize shoutbox controller. No context provided")
    return this
  }

  this.init()
  return this
}

// Cache the important elements, enable autoscroll, and watch the input length.
ShoutboxController.prototype.init = function() {
  const self = this
  self.$input = self.$context.find(".shout_input")
  self.$button = self.$context.find('input[type="submit"]')
  self.$messageBox = null

  initShoutboxAutoscroll()

  self.$input.bind("keyup change", function() {
    self.updateInputState()
  })

  self.updateInputState()
  return self
}

// Disable or enable the submit button based on the current message length.
ShoutboxController.prototype.updateInputState = function() {
  if (this.$input.val().length > 100) {
    this.disableShoutbox()
  } else {
    this.enableShoutbox()
  }
}

// Show or clear the length warning message for the shout form.
ShoutboxController.prototype.writeMessage = function(message) {
  if (message === undefined) return this.removeMessageBox()
  this.createMessageBox().html(message)
  return this
}

// Create the warning paragraph once and reuse it for future status messages.
ShoutboxController.prototype.createMessageBox = function() {
  if (this.$messageBox) return this.$messageBox
  this.$messageBox = $("<p/>", { class: "shout-warning" }).appendTo(this.$context.find(".fields"))
  return this.$messageBox
}

// Remove the warning message when the input is back in range.
ShoutboxController.prototype.removeMessageBox = function() {
  if (this.$messageBox) {
    this.$messageBox.remove()
    this.$messageBox = null
  }
  return this
}

// Report whether the submit button is currently disabled.
ShoutboxController.prototype.isDisabled = function() {
  return this.$button.prop("disabled") === true
}

// Block submission and show the current character count when the message is too long.
ShoutboxController.prototype.disableShoutbox = function() {
  const chars = this.$input.val().length
  this.writeMessage(["Maximum shout length exceeded (", chars, "/100)"].join(""))
  this.$button.prop("disabled", true)
}

// Re-enable submission and clear any warning once the message is short enough.
ShoutboxController.prototype.enableShoutbox = function() {
  if (!this.$button.prop("disabled")) {
    return this
  }
  this.writeMessage()
  this.$button.prop("disabled", false)
}

window.ShoutboxController = ShoutboxController
