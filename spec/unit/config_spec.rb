require_relative "../spec_common"

include SpecCommon

describe Ocp::Registry do

	describe "Validate config" do

		it "validates configuration file" do
      expect {
        Ocp::Registry.configure("foobar")
      }.to raise_error(Ocp::Registry::ConfigError, /Invalid config format/)

      config = default_config.merge("http" => nil)

      expect {
        Ocp::Registry.configure(config)
      }.to raise_error(Ocp::Registry::ConfigError, /HTTP configuration is missing/)

      config = default_config.merge("db" => nil)

      expect {
        Ocp::Registry.configure(config)
      }.to raise_error(Ocp::Registry::ConfigError, /Database configuration is missing/)

      config = default_config.merge("cloud" => nil)

      expect {
        Ocp::Registry.configure(config)
      }.to raise_error(Ocp::Registry::ConfigError, /Cloud configuration is missing/)

      config = default_config
      config["cloud"]["plugin"] = nil

      expect {
        Ocp::Registry.configure(config)
      }.to raise_error(Ocp::Registry::ConfigError, /Cloud plugin is missing/)

      config = default_config
      config["cloud"]["login_url"] = nil

      expect {
        Ocp::Registry.configure(config)
      }.to raise_error(Ocp::Registry::ConfigError, /Cloud Login URL is missing/)

      config = default_config

      config["cloud"]["plugin"] = "supercloud"
      expect {
        Ocp::Registry.configure(config)
      }.to raise_error(Ocp::Registry::ConfigError, /Could not find Provider Plugin/)
    end

    it "Use mock cloud" do

    	config = default_config
    	config["cloud"]["plugin"] = "mock"
    	config["cloud"]["mock"] = {
	      	"auth_url" => "http://www.mockcloud.com:6555/v1.0" ,
	      	"username" => "admin" ,
	      	"api_key" => "mockadmin" ,
	      	"tenant" => "admin"
	    	}

	    Ocp::Registry.configure(config)

	    logger = Ocp::Registry.logger

      logger.should be_kind_of(Logger)
      logger.level.should == Logger::DEBUG

      Ocp::Registry.http_port.should == 6677
      Ocp::Registry.http_user.should == "admin"
      Ocp::Registry.http_password.should == "admin"

      db = Ocp::Registry.db
      db.should be_kind_of(Sequel::SQLite::Database)
      db.opts[:database].should == ":memory:"

      im = Ocp::Registry.application_manager
      im.should be_kind_of(Ocp::Registry::ApplicationManager)

	  end

	end

	describe "Database configuration" do

		it "connect db" do
			db_config = default_config["db"]
			db = Ocp::Registry.connect_db(db_config)

			db.database_type.should == "sqlite"
		end

		it "migrate_db" do
		end

	end

	describe "Mail configuration" do

		it "init mail client" do
		end

	end


end