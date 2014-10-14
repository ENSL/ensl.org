ENSL.GatherServer = DS.Model.extend({
	votes: DS.attr('number', { defaultValue: 0 }),

	server: DS.belongsTo('server')
});
