
module Ocp::Registry

  class CloudManager

    class Openstack < CloudManager

      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Ocp::Registry.logger

        @openstack_properties = cloud_config["openstack"]

        unless @openstack_properties["auth_url"].match(/\/tokens$/)
          @openstack_properties["auth_url"] = @openstack_properties["auth_url"] + "/tokens"
        end

        @openstack_options = {
          :provider => "OpenStack",
          :openstack_auth_url => @openstack_properties["auth_url"],
          :openstack_username => @openstack_properties["username"],
          :openstack_api_key => @openstack_properties["api_key"],
          :openstack_tenant => @openstack_properties["tenant"],
          :openstack_region => @openstack_properties["region"],
          :openstack_endpoint_type => @openstack_properties["endpoint_type"]
        }
      end

      def openstack
        @openstack ||= Fog::Compute.new(@openstack_options)
      end
      
      def validate_options(cloud_config)
        unless cloud_config.has_key?("openstack") &&
            cloud_config["openstack"].is_a?(Hash) &&
            cloud_config["openstack"]["auth_url"] &&
            cloud_config["openstack"]["username"] &&
            cloud_config["openstack"]["api_key"] &&
            cloud_config["openstack"]["tenant"]
          raise ConfigError, "Invalid OpenStack configuration parameters"
        end
      end

      def create_tenant

      end

      def create_user
        
      end

      def add_user_to_tenant
        
      end

    end

  end

end