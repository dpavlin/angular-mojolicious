
if (typeof (console) === 'undefined') console = { debug: function() {} }; // mock console.debug

function Registration($resource,$xhr){
	this.master = {
		person: {
			name: '', surname: '', inst: '', email: ''
		},
		type: 'participant',
		work: {
			title: '',
			abstract: '',
			authors:[ { name:'', surname:'', inst:'', email:'' } ],
			organizers: []
		},
		symposium: { 
			organizers: [], 
			work_nr: 1 
		}
	};
	this.Registration = $resource( '/data/:database/Registration/:id', { id:'', database: database } );
	this.reset();
	this.$watch('$location.hashPath', this.hash_change);
	this.$xhr = $xhr;
	console.debug( 'database', database );
}
Registration.$inject=['$resource','$xhr'];

Registration.prototype = {
	hash_change: function() {
		var id = this.$location.hashPath;
console.debug( 'hash_change', id, this.registration.$id );
		if ( id != this.registration.$id ) {
			if (id) {
				var self = this;
				this.Registration.get({ id: id }, function(registration) {
console.debug('registration', id, registration);
					self.last_saved = angular.copy(registration);
					self.registration = registration; // needed for load_symposium below
					self.load_symposium();
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
					registration.symposium.$id = registration.$id; // reuse $id of first work for symposium
					self.symposium = angular.copy( self.registration.symposium );
					self.symposium.works = [];
				}
				registration.work.$id = registration.$id; // preserve $id
				self.symposium.works[ registration.symposium.work_nr - 1 ] = registration.work;

				//self.symposium.$save();
				//self.load_symposium();
			}

			self.last_saved = angular.copy(registration);
		});
	},
	load_symposium: function() {
		var self = this;
		if ( self.registration.type != 'symposium' ) return;

		var s_id = self.registration.$id;
		if ( self.registration.symposium ) s_id = self.registration.symposium.$id;

		if ( self.symposium && self.symposium.$id == s_id ) {
			console.debug('load_symposium ', s_id, ' allready loaded');
			return;
		}

		self.symposium = angular.copy( self.registration.symposium );
		self.symposium.works = [];
		// first registration doesn't have symposium.$id, but we used same $id
console.debug( 'load_symposium ', s_id, self.symposium );

console.debug( self.$xhr );

		self.$xhr("JSON"
			, "/conference/_design/symposium/_view/works?callback=JSON_CALLBACK;key=" + s_id
			, function(code, response){ 
console.log('symposium/_view/works', code, response);
				angular.foreach( response.rows, function(row) {
					var work = row.value.work;
					work.$id = row.value.$id; // copy $id so we can select correct one in list
					self.symposium.works.push( work );
				} );
console.debug( 'symposium', self.symposium );
			}
		); 
	}
};

angular.validator.max_length = function(input, len) {
	var ok = input.length <= len;
console.debug( 'max_length', ok, input.length, len );
	return ok ? '' : 'must be shorter than '+len+' characters';
}

