ENSL.GatherMap = DS.Model.extend({
	votes: DS.attr('number', { defaultValue: 0 }),

	map: DS.belongsTo('map')
});
