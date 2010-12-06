
if (typeof (console) === 'undefined') console = { debug: function() {} }; // mock console.debug

var database = 'casopisi2010';

function Upitnik($resource,$xhr){
	this.master = {
		casopisi: [{naslov:''},{naslov:''},{naslov:''}],
		eizvori: [{naziv:''}]
	};
	this.Upitnik = $resource( '/data/:database/Upitnik/:id', { id:'', database: database } );
	this.reset();
	this.$watch('$location.hashPath', this.hash_change);
	this.$xhr = $xhr;
	console.debug( 'database', database, this.upitnik );
}
Upitnik.$inject=['$resource','$xhr'];

Upitnik.prototype = {
	hash_change: function() {
		var id = this.$location.hashPath;
console.debug( 'hash_change', id, this.upitnik.$id );
		if ( id != this.upitnik.$id ) {
			if (id) {
				var self = this;
				this.Upitnik.get({ id: id }, function(upitnik) {
console.debug('upitnik', id, upitnik);
					self.last_saved = angular.copy(upitnik);
					self.upitnik = upitnik; // needed for load_symposium below
				});
			}
			else this.reset();
		}
	},
	reset: function() {
		console.debug( this.Upitnik );
		this.upitnik = new this.Upitnik( this.master );
console.debug( 'reset', this.upitnik );
		this.last_saved = this.upitnik;
	},
	save: function(){
		var self = this;
		this.upitnik.$save(function(upitnik){
			self.$location.hashPath = upitnik.$id;
			self.last_saved = angular.copy(upitnik);
		});
	}
};

