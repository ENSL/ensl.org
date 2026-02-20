// Shoutbox Controller manages input validation on shoutmsg form

function scrollToBottom(el) {
	el.scrollTop = el.scrollHeight;
}

function initShoutboxAutoscroll() {
	var $transcripts = $(".shoutbox-messages");
	$transcripts.each(function() {
		var el = this;
		// Keep transcript pinned to the latest message.
		scrollToBottom(el);

		// Avoid registering multiple observers on the same element.
		if (el.dataset && el.dataset.shoutboxAutoscroll === "1") {
			return;
		}
		if (el.dataset) {
			el.dataset.shoutboxAutoscroll = "1";
		}

		// Turbo stream updates mutate the transcript DOM; re-scroll after updates.
		var observer = new MutationObserver(function() {
			setTimeout(function() { scrollToBottom(el); }, 10);
		});
		observer.observe(el, { childList: true, subtree: true });
	});
}

function bindShoutboxHandlers() {
	// Main shoutbox mousewheel scrolling behavior.
	$(document).off('mousewheel', 'div#shoutbox');
	$(document).on('mousewheel', 'div#shoutbox', function(ev, delta) {
		var scrollTop = $(this).scrollTop();
		$(this).scrollTop(scrollTop - Math.round(delta));
	});

	// Prevent double-submit while a shout request is in flight.
	$(document).off('submit', 'form.new_shoutmsg');
	$(document).on('submit', 'form.new_shoutmsg', function() {
		$('input[type=submit]', this).attr('disabled', 'disabled');
	});

	// Re-enable submit after Rails UJS ajax completion and reset form.
	$(document).off('ajax:complete', 'form.new_shoutmsg');
	$(document).on('ajax:complete', 'form.new_shoutmsg', function() {
		var self = this;
		$(this)[0].reset();
		setTimeout(function() {
			$('input[type=submit]', self).removeAttr('disabled');
		}, 2000);
	});
}

[
	"DOMContentLoaded",
	"turbo:load",
	"turbo:render",
	"turbo:frame-load"
].forEach(function(eventName) {
	document.addEventListener(eventName, initShoutboxAutoscroll);
	document.addEventListener(eventName, bindShoutboxHandlers);
});

// Run again right before Turbo renders stream actions.
document.addEventListener("turbo:before-stream-render", function() {
	setTimeout(initShoutboxAutoscroll, 0);
});

function ShoutboxController (options) {
	if (!(this instanceof ShoutboxController)) {
    return new ShoutboxController(options);
  }
	this.options = options || {};
	this.$context = this.options.context || $();

	if (!this.$context.length) {
		console.log("Unable to initialize shoutbox controller. No context provided");
		return this;
	}

	this.init();
	return this;
}

// Initialize shoutbox state.
ShoutboxController.prototype.init = function () {
	var self = this;
	self.$input = self.$context.find(".shout_input");
	self.$button = self.$context.find('input[type="submit"]');
	self.$messageBox = null;

	// Ensure autoscroll is initialized for all shoutbox transcripts.
	initShoutboxAutoscroll();

	self.$input.bind("keyup change", function () {
		self.updateInputState();
	});

	// Initialize button state based on current input value.
	self.updateInputState();
	return self;
};

// Keeps button/message state in sync with current input length.
ShoutboxController.prototype.updateInputState = function () {
	if (this.$input.val().length > 100) {
		this.disableShoutbox();
	} else {
		this.enableShoutbox();
	}
};

// Displays a message if present; otherwise removes the message element.
ShoutboxController.prototype.writeMessage = function (message) {
	if (message === undefined) return this.removeMessageBox();
	this.createMessageBox().html(message);
	return this;
};

// Adds message box to DOM and cache.
ShoutboxController.prototype.createMessageBox = function () {
	if (this.$messageBox) return this.$messageBox;
	this.$messageBox = $("<p/>", {class: "shout-warning"}).appendTo(this.$context.find(".fields"));
	return this.$messageBox;
};

// Removes message box from DOM and cache.
ShoutboxController.prototype.removeMessageBox = function () {
	if (this.$messageBox) {
		this.$messageBox.remove();
		this.$messageBox = null;
	}
	return this;
};

// Returns true if button is disabled.
ShoutboxController.prototype.isDisabled = function () {
	return this.$button.prop("disabled") === true;
};

// Disables submit button and shows warning.
ShoutboxController.prototype.disableShoutbox = function () {
	var chars = this.$input.val().length;
	this.writeMessage(["Maximum shout length exceeded (",chars,"/100)"].join(""));
	this.$button.prop("disabled", true);
};

// Removes warning and enables shoutbox submit.
ShoutboxController.prototype.enableShoutbox = function () {
	if (!this.$button.prop("disabled")) {
		return this;
	}
	// Remove any warnings
	this.writeMessage();
	this.$button.prop("disabled", false);
};