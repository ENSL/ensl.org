Ember.Handlebars.helper('flag', function(country) {
	if (country) {
		return new Ember.Handlebars.SafeString('<img src="/assets/flags/' + country + '.png" class="flag" />');
	}
	return new Ember.Handlebars.SafeString('<img src="/assets/flags/EU.png" class="flag" />');
});

Ember.Handlebars.helper('votingBar', function(name, current, total) {
	var bar = '<div class="voting-bar"><div class="label">' + name + '</div>';
	bar += '<div class="vote-progress"><div style="width: ' + Math.round(current/total*100) + '%"></div></div></div>';
	return new Ember.Handlebars.SafeString(bar);
});
