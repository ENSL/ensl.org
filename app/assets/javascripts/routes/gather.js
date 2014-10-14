ENSL.GatherRoute = ENSL.FullLayoutRoute.extend({
	templateName: 'gathers/gather',

	model: function(params) {
		return this.store.find('gather', params.gather_id);
	},
});
