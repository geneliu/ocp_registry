
module Ocp::Registry

  class CloudManager

    class Openstack < CloudManager

      require 'openstack/cinder_helper'
      require 'openstack/nova_helper'
      require 'openstack/keystone_helper'

      include KeystoneHelper
      include NovaHelper
      include CinderHelper

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
          :openstack_endpoint_type => @openstack_properties["endpoint_type"]
        }
        @default_role_name =  cloud_config["default_role"]
        default_role
      end

      def logger
        @logger
      end

      def compute
        @compute ||= Fog::Compute.new(@openstack_options)
      end

      def keystone
        @keystone ||= Fog::Identity.new(@openstack_options)
      end
      
      def volume
        @volume ||= Fog::Volume.new(@openstack_options)
      end

      def validate_options(cloud_config)
        unless cloud_config.has_key?("openstack") &&
            cloud_config["openstack"].is_a?(Hash) &&
            cloud_config["openstack"]["auth_url"] &&
            cloud_config["openstack"]["username"] &&
            cloud_config["openstack"]["api_key"] &&
            cloud_config["openstack"]["tenant"] &&
            cloud_config["default_role"]
          raise ConfigError, "Invalid OpenStack configuration parameters"
        end
      end

      def set_tenant_quota(tenant_id, settings={})
        with_openstack do
          compute_quota = set_compute_quota(tenant_id, settings)
          volume_quota = set_volume_quota(tenant_id, settings)
        end
        result =  compute_quota.merge (volume_quota) if (compute_quota && volume_quota)
        cloud_error "Quota for #{tenant_id} has not been set" unless result
        result
      end

      def default_quota
        return @default_quota if @default_quota
        with_openstack do
          compute_quota = default_compute_quota
          volume_quota = default_volume_quota
          @default_quota = compute_quota.merge (volume_quota)
        end
        cloud_error "Default Quota is not found" unless @default_quota
        @default_quota
      end

      def default_role
        with_openstack do 
          @default_role ||= get_role_by_name(@default_role_name)
        end
        cloud_error "Default Role [#{cloud_config["default_role"]}] is not found" unless @default_role
        @default_role
      end

      def with_openstack
        retried = false
        begin
          yield
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @compute = nil
            @volume = nil
            @keystone = nil
            retry
          end
          cloud_error "Unable to connect to OpenStack API: #{e.message}", e
        rescue Excon::Errors::InternalServerError => e
          cloud_error "OpenStack API Internal Server error. Check debug log for details.", e
        end
      end

      def cloud_error(message, exception = nil)
        @logger.error(message) if @logger
        @logger.error(exception) if @logger && exception
        raise Ocp::Registry::CloudError, message
      end

    end

  end

end