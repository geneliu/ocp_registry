module Ocp::Registry

	class CloudManager

		class Openstack 

			module CinderHelper
				CINDER_QUOTA_FIELDS = ["volumes", "snapshots", "gigabytes"]

				def default_volume_quota
					volume.get_quota_defaults(nil).body["quota_set"]
				end

				def set_volume_quota(tenant_id, hash)
					settings = Ocp::Registry::Common.hash_filter(hash, CINDER_QUOTA_FIELDS)
					volume.update_quota(tenant_id, settings).body["quota_set"]
				end

			end

		end

	end

end
