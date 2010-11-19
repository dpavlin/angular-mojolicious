
Symposiums.$inject = ['$xhr', '$route']; 

function Symposiums(xhr, route){ 

	this.route = route; 
	this.xhr = xhr; 

	var data = {}
	this.data = data;

	this.xhr("JSON"
		, "/"+database+"/_design/symposium/_view/work_nr%2Ctitle?callback=JSON_CALLBACK"
		, function(code, response){ 
			console.log(code, response, data);
			data.response = response;
		}
	); 
}

