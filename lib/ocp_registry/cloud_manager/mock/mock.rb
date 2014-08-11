# TODO mock and spec are old and not updated to ocpchinalab havana
module Ocp::Registry
	  class CloudManager

    class Mock < CloudManager 
    	def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Ocp::Registry.logger

        @mock_properties = cloud_config["mock"]

        unless @mock_properties["auth_url"].match(/\/tokens$/)
          @mock_properties["auth_url"] = @mock_properties["auth_url"] + "/tokens"
        end

        @mock_options = {
          :provider => "mock",
          :mock_auth_url => @mock_properties["auth_url"],
          :mock_username => @mock_properties["username"],
          :mock_api_key => @mock_properties["api_key"],
          :mock_tenant => @mock_properties["tenant"],
          :mock_endpoint_type => @mock_properties["endpoint_type"]
        }
        @default_role_name =  cloud_config["default_role"]
      end

      def validate_options(cloud_config)
        unless cloud_config.has_key?("mock") &&
            cloud_config["mock"].is_a?(Hash) &&
            cloud_config["mock"]["auth_url"] &&
            cloud_config["mock"]["username"] &&
            cloud_config["mock"]["api_key"] &&
            cloud_config["mock"]["tenant"] &&
            cloud_config["default_role"]
          raise ConfigError, "Invalid mock configuration parameters"
        end
      end

      def default_compute_quota
      	{
          "injected_file_content_bytes"=>10240, 
          "metadata_items"=>128, 
          "ram"=>51200, 
          "floating_ips"=>10, 
          "key_pairs"=>100, 
          "id"=>"defaults", 
          "instances"=>10, 
          "security_group_rules"=>20, 
          "injected_files"=>5, 
          "cores"=>20, 
          "fixed_ips"=>-1, 
          "injected_file_path_bytes"=>255, 
          "security_groups"=>10
        }
      end

      def default_volume_quota
      	{
          "gigabytes"=>1000, 
          "volumes"=>10, 
          "id"=>"defaults", 
          "snapshots"=>10
        }
      end

      def default_quota
        return @default_quota if @default_quota
        compute_quota = default_compute_quota
        volume_quota = default_volume_quota
        @default_quota = compute_quota.merge (volume_quota)
        cloud_error "Default Quota is not found" unless @default_quota
        @default_quota
      end

      def get_role_by_name(name)
      	role = {
                  :id => "08bc68483a804ee59f4290256a8003c6",
                  :name => name
              	}
        Model.new role
      end

      def default_role
        return @default_role if @default_role
        @default_role ||= get_role_by_name(@default_role_name)
        cloud_error "Default Role [#{cloud_config["default_role"]}] is not found" unless @default_role
        @logger.info("Default Role #{@default_role.name} - #{@default_role.id}")
        @default_role
      end 

      def set_tenant_quota(tenant_id, settings={})
        result = nil
        compute_quota = set_compute_quota(tenant_id, settings)
        volume_quota = set_volume_quota(tenant_id, settings)
        result =  compute_quota.merge (volume_quota) if (compute_quota && volume_quota)
        cloud_error "Quota for #{tenant_id} has not been set" unless result
        result
      end


      def cloud_error(message, exception = nil)
        @logger.error(message) if @logger
        @logger.error(exception) if @logger && exception
        raise Ocp::Registry::CloudError, message
      end

			CINDER_QUOTA_FIELDS = ["volumes", "snapshots", "gigabytes"]


			def set_volume_quota(tenant_id, hash)
				settings = Ocp::Registry::Common.hash_filter(hash, CINDER_QUOTA_FIELDS)
        {
          "gigabytes"=>1000, 
          "volumes"=>10, 
          "id"=>"defaults", 
          "snapshots"=>10
        }.merge settings
			end

			def create_tenant(name, description, enabled = true)
      tenant = {
        :name => name,
        :description => description,
        :enabled => enabled,
        :id => "1bb0fed1c2df4b5faa19e7700c049e35"
      }
      Model.new tenant
      end

      def create_user(name, tenant_id, password, email = '')
      user = {
        :email => email,
        :enabled => true,
        :name => name,
        :tenant_id => tenant_id, 
        :password => password, 
        :id => "2df4b5faa19c049e351bb0fed1caa19e7700"
      }
      Model.new user
      end

      def get_tenant_by_name(name)
    	 nil
      end

      def tenant_add_user_with_role(tenant, user_id, role_id)
        true
      end

      def find_user_by_name(name)
    	 nil
      end

			NOVA_QUOTA_FIELDS = ["metadata_items",
			                     "cores",
			                     "instances",
			                     "injected_files",
			                     "injected_file_content_bytes",
			                     "ram",
			                     "floating_ips",
			                     "fixed_ips",
			                     "security_groups",
			                     "security_group_rules"]

			def set_compute_quota(tenant_id, hash)
				settings = Ocp::Registry::Common.hash_filter(hash, NOVA_QUOTA_FIELDS)
        {
          "injected_file_content_bytes"=>10240, 
          "metadata_items"=>128, "ram"=>51200, 
          "floating_ips"=>10, 
          "key_pairs"=>100, 
          "id"=>"defaults", 
          "instances"=>10, 
          "security_group_rules"=>20, 
          "injected_files"=>5, 
          "cores"=>20, 
          "fixed_ips"=>-1, 
          "injected_file_path_bytes"=>255, 
          "security_groups"=>10
        }.merge settings
			end

    end
  end
end