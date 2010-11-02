angular.service('conference', function($resource){
 this.Work = $resource( '/data/conference/Work/:_id', { _id:'' } );
}, {$inject:['$resource'],$creation:'eager'});

function Work(){
	this.master = {
		type: '',
		title: '',
		abstract: '',
		authors:[ { name:'', surname:'', inst:'', email:'' } ],
	};
	this.reset();
	this.$watch('$location.hashPath', this.hash_change);
}

Work.prototype = {
	hash_change: function() {
		var id = this.$location.hashPath;
		if ( id ) {
			this.work = this.Work.get({ _id: id });
		}
	},
	reset: function() {
		this.work = new this.Work( this.master );
	},
	save: function(){
		var l = this.$location;
		this.work.$save(function(work){
			l.hashPath = work._id;
		});
	}
};