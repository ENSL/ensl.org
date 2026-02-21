function scrollToBottom(el) {
  el.scrollTop = el.scrollHeight
}

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

["DOMContentLoaded", "turbo:load", "turbo:render", "turbo:frame-load"].forEach(function(eventName) {
  document.addEventListener(eventName, initShoutboxAutoscroll)
  document.addEventListener(eventName, bindShoutboxHandlers)
})

document.addEventListener("turbo:before-stream-render", function() {
  setTimeout(initShoutboxAutoscroll, 0)
})

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

ShoutboxController.prototype.updateInputState = function() {
  if (this.$input.val().length > 100) {
    this.disableShoutbox()
  } else {
    this.enableShoutbox()
  }
}

ShoutboxController.prototype.writeMessage = function(message) {
  if (message === undefined) return this.removeMessageBox()
  this.createMessageBox().html(message)
  return this
}

ShoutboxController.prototype.createMessageBox = function() {
  if (this.$messageBox) return this.$messageBox
  this.$messageBox = $("<p/>", { class: "shout-warning" }).appendTo(this.$context.find(".fields"))
  return this.$messageBox
}

ShoutboxController.prototype.removeMessageBox = function() {
  if (this.$messageBox) {
    this.$messageBox.remove()
    this.$messageBox = null
  }
  return this
}

ShoutboxController.prototype.isDisabled = function() {
  return this.$button.prop("disabled") === true
}

ShoutboxController.prototype.disableShoutbox = function() {
  const chars = this.$input.val().length
  this.writeMessage(["Maximum shout length exceeded (", chars, "/100)"].join(""))
  this.$button.prop("disabled", true)
}

ShoutboxController.prototype.enableShoutbox = function() {
  if (!this.$button.prop("disabled")) {
    return this
  }
  this.writeMessage()
  this.$button.prop("disabled", false)
}

window.ShoutboxController = ShoutboxController
