function Symposium($resource){
	this.master = {
		type: '',
		title: '',
		abstract: '',
		authors:[ { name:'', surname:'', inst:'', email:'' } ],
	};
	this.Symposium = $resource( '/data/conference/Symposium/:_id', { _id:'' } );
	this.reset();
	this.$watch('$location.hashPath', this.hash_change);
}
Symposium.$inject=['$resource'];

Symposium.prototype = {
	hash_change: function() {
		var id = this.$location.hashPath;
		if ( id ) {
			this.symposium = this.Symposium.get({ _id: id });
		}
	},
	reset: function() {
		console.debug( this.Symposium );
		this.symposium = new this.Symposium( this.master );
	},
	save: function(){
		var l = this.$location;
		this.symposium.$save(function(symposium){
			l.hashPath = symposium._id;
		});
	}
};
