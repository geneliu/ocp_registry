module Ocp::Registry
	class CloudManager

    class Mock < CloudManager 
    	class Model
	    	def initialize(properties)
	    		if properties.is_a? (Hash)
	    			@properties = properties
	    		end
	    	end

	    	def method_missing(method, *args)
	    		return @properties[method.to_sym]
	    	end

	    	def to_json
	    		Yajl::Encoder.encode(@properties)
	    	end
    	end
    end
  end
end