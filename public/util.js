var util={
	/*
		@param now, last are two objects, i.e. key-value pair sets.
	*/
	whoChanged: function(now, last){
		var ret={};
		$.each(now, function(i,v){
			if(last[i]!=v) {ret[i]=[v, last[i]];}
		});

		return ret;
	}

};