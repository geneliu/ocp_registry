
module Ocp::Registry

  class << self

    attr_accessor :logger
    attr_accessor :base_url
    attr_accessor :http_port
    attr_accessor :http_user
    attr_accessor :http_password
    attr_accessor :db
    attr_accessor :application_manager
    attr_accessor :cloud_login_url

    def configure(config)
      validate_config(config)

      @logger ||= Logger.new(config["logfile"] || STDOUT)
      if config["loglevel"].kind_of?(String)
        @logger.level = Logger.const_get(config["loglevel"].upcase)
      end

      @base_url = config["http"]["base_url"] || "127.0.0.1"
      @http_port = config["http"]["port"]
      @http_user = config["http"]["user"]
      @http_password = config["http"]["password"]

      @db = connect_db(config["db"])

      migrate_db if @db

      @cloud_login_url = config["cloud"]["login_url"]
      
      plugin = config["cloud"]["plugin"]
      begin
        require "ocp_registry/cloud_manager/#{plugin}"
      rescue LoadError
        raise ConfigError, "Could not find Provider Plugin: #{plugin}"
      end
      @cloud_manager = Ocp::Registry::CloudManager.const_get(plugin.capitalize).new(config["cloud"])
      
      @mail_client = init_mail_client(config["mail"]) if config["mail"]
      
      @application_manager = Ocp::Registry::ApplicationManager.new(@cloud_manager,@mail_client)
    end

    def init_mail_client(mail_config)
      require "ocp_registry/mail_client"
      MailClient.new(mail_config)
    end

    def migrate_db
      Sequel.extension :migration
      Sequel::Migrator.apply(@db,File.expand_path(File.join(File.dirname(__FILE__), 'db')))
    end

    def connect_db(db_config)
      connection_options = db_config.delete('connection_options') {{}}
      db_config.delete_if { |_, v| v.to_s.empty? }
      db_config = db_config.merge(connection_options)

      db = Sequel.connect(db_config)
      if logger
        db.logger = @logger
        db.sql_log_level = :debug
      end

      db
    end

    def validate_config(config)
      unless config.is_a?(Hash)
        raise ConfigError, "Invalid config format, Hash expected, " \
                           "#{config.class} given"
      end

      unless config.has_key?("http") && config["http"].is_a?(Hash)
        raise ConfigError, "HTTP configuration is missing from config file"
      end

      unless config.has_key?("db") && config["db"].is_a?(Hash)
        raise ConfigError, "Database configuration is missing from config file"
      end

      unless config.has_key?("cloud") && config["cloud"].is_a?(Hash)
        raise ConfigError, "Cloud configuration is missing from config file"
      end

      if config["cloud"]["plugin"].nil?
        raise ConfigError, "Cloud plugin is missing from config file"
      end
    end

  end

end