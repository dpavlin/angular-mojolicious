
if (typeof (console) === 'undefined') console = { debug: function() {} }; // mock console.debug

function Registration($resource){
	this.master = {
		person: {
			name: '', surname: '', inst: '', email: ''
		},
		type: 'participant',
		work: {
			title: '',
			abstract: '',
			authors:[ { name:'', surname:'', inst:'', email:'' } ]
		},
		symposium: { organizers: [ {name:'', surname:'', inst:'', email:'' } ], work_nr: 1 }
	};
	this.Registration = $resource( '/data/conference/Registration/:id', { id:'' } );
	this.Symposium = $resource( '/data/conference/Symposium/:id', { id:'' } );
	this.reset();
	this.$watch('$location.hashPath', this.hash_change);
}
Registration.$inject=['$resource'];

Registration.prototype = {
	hash_change: function() {
		var id = this.$location.hashPath;
console.debug( 'hash_change', id, this.registration.$id );
		if ( id != this.registration.$id ) {
			if (id) {
				var self = this;
				this.registration = this.Registration.get({ id: id }, function(registration) {
					self.last_saved = angular.copy(registration);
					if ( registration.type == 'symposium' ) {
						var s_id = registration.symposium.$id || registration.$id;
						// first registration doesn't have symposium.$id, but we used same $id
console.debug( 'load symposium ', s_id );
						self.symposium = self.Symposium.get({ id: s_id });
					}
				});
			}
			else this.reset();
		}
	},
	reset: function() {
		console.debug( this.Registration );
		var last = this.registration;
		if ( last && last.type == 'symposium' ) {
			if ( last.$id ) last.symposium.work_nr++; // only if saved
		}
		this.registration = new this.Registration( this.master );
		if ( last ) {
			this.registration.type      = last.type;
			this.registration.person    = last.person;

			if ( last.type == 'symposium' )
			this.registration.symposium = last.symposium;
		}
		this.last_saved = angular.copy( this.registration ); // FIXME was: {};
console.debug( 'reset', this.registration, this.$location.hashPath, last );
	},
	save: function(){
		var self = this;
		this.registration.$save(function(registration){
			self.$location.hashPath = registration.$id;

			// save symposium to separate resource
			if ( registration.type == 'symposium' ) {
				if ( ! self.symposium ) { 
					self.registration.symposium.$id = registration.$id; // reuse $id of first work for symposium
					self.symposium = new self.Symposium( registration.symposium );
					self.symposium.works = [];
				}
				registration.work.$id = registration.$id; // preserve $id
				self.symposium.works[ registration.symposium.work_nr - 1 ] = registration.work;
console.debug('save_symposium', self.symposium );
				self.symposium.$save();
			}

			self.last_saved = angular.copy(registration);
		});
	}
};

angular.validator.max_length = function(input, len) {
	var ok = input.length <= len;
console.debug( 'max_length', ok, input.length, len );
	return ok ? '' : 'must be shorter than '+len+' characters';
}

