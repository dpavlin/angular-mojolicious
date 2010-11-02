function Work($resource){
	this.master = {
		type: '',
		title: '',
		abstract: '',
		authors:[ { name:'', surname:'', inst:'', email:'' } ],
	};
	this.Work = $resource( '/data/conference/Work/:_id', { _id:'' } );
	this.reset();
	this.$watch('$location.hashPath', this.hash_change);
}
Work.$inject=['$resource'];

Work.prototype = {
	hash_change: function() {
		var id = this.$location.hashPath;
		if ( id ) {
			this.work = this.Work.get({ _id: id });
		}
	},
	reset: function() {
		console.debug( this.Work );
		this.work = new this.Work( this.master );
	},
	save: function(){
		var l = this.$location;
		this.work.$save(function(work){
			l.hashPath = work._id;
		});
	}
};
