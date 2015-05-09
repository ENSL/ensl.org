// Shoutbox Controller manages input validation on shoutmsg form

function ShoutboxController (options) {
	if (!(this instanceof ShoutboxController)) {
    return new ShoutboxController(options);
  }
  this.options = options;
	this.$context = options.context;
	if (this.$context.length) {
		this.init(options);
	} else {
		console.log("Unable to initialize shoutbox controller. No context provided");
	}
	return this;
}

// Initialise shoutbox state
ShoutboxController.prototype.init = function (options) {
	var self = this;
	self.$input = self.$context.find(".shout_input");
	self.$button = self.$context.find('input[type="submit"]');
	self.$messageBox = null;
	self.$input.bind("keyup change", function () {
		if (self.$input.val().length > 100) {
			self.disableShoutbox();
		} else {
			self.enableShoutbox();
		}
	});
	return self;
};

// Displays a message if `message` present, otherwise removes message elemt
ShoutboxController.prototype.writeMessage = function (message) {
	if (message === undefined) return this.removeMessageBox();
	this.createMessageBox().html(message);
	return this;
};

// Adds message box to DOM and cache
ShoutboxController.prototype.createMessageBox = function () {
	if (this.$messageBox) return this.$messageBox;
	this.$messageBox = $("<p/>", {class: "shout-warning"}).appendTo(this.$context.find(".fields"));
	return this.$messageBox;
};

// Removes message box from DOM and cache
ShoutboxController.prototype.removeMessageBox = function () {
	if (this.$messageBox) {
		this.$messageBox.remove();
		this.$messageBox = null;
	}
	return this;
};

// Returns true if button is disabled
ShoutboxController.prototype.isDisabled = function () {
	return this.$button.prop("disabled") === true;
};

// Disables Input Button
ShoutboxController.prototype.disableShoutbox = function () {
	var chars = this.$input.val().length;
	this.writeMessage(["Maximum shout length exceeded (",chars,"/100)"].join(""));
	this.$button.prop("disabled", true);
};

// Removes any warnings and enableds shoutbox submit
ShoutboxController.prototype.enableShoutbox = function () {
	if (!this.$button.prop("disabled")) {
		return this;
	}
	// Remove any warnings
	this.writeMessage();
	this.$button.prop("disabled", false);
};