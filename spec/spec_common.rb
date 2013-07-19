module SpecCommon

	require_relative "../lib/ocp_registry"

	def default_config
		{
	    "logfile" => nil,
	    "loglevel" => "debug",
	    "http" => {
	      "user" => "admin",
	      "password" => "admin",
	      "port" => 6677
	    },
	    "db" => {
	      "database" => ":memory:",
	      "adapter" => "sqlite"
	    },
	    "cloud" => {
	    	"login_url" => "http://www.mockcloud.com/dashboard",
	      "default_role" => "Member"
	    }
		}
	end

end