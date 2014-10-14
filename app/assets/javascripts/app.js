/**
 * app.js is for the ember specific application
 */

//= require jquery
//= require handlebars
//= require ember
//= require es5-shim/es5-shim
//= require es5-shim/es5-sham
//= require ember-data-local
//= require_self

//= require router
//= require helpers
//= require_directory ./routes
//= require_directory ./controllers
//= require_directory ./models
//= require_tree ./templates

window.ENSL = Ember.Application.create({
	rootElement: '#content'
});

ENSL.ApplicationAdapter = DS.ActiveModelAdapter.extend({
});

ENSL.Router.reopen({
	location: 'history'
});

ENSL.ApplicationRoute = Ember.Route.extend({
});

ENSL.FullLayoutView = Ember.View.extend({
	layoutName: 'layouts/full'
});

ENSL.FullLayoutRoute = Ember.Route.extend({
	renderTemplate: function(controller, model) {
		this.render(this.templateName, {
			view: 'full_layout',
		});
	}
});

