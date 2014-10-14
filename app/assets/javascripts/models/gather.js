ENSL.Gather = DS.Model.extend({
	status: DS.attr(),
	votes: DS.attr(),
	turn: DS.attr(),
	lastpick1: DS.attr(),
	lastpick2: DS.attr(),

	category: DS.belongsTo('category'),
	gatherers: DS.hasMany('gatherer'),
	gatherServers: DS.hasMany('gatherServer'),
	gatherMaps: DS.hasMany('gatherMap')
});
