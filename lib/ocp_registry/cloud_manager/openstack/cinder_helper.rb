module Ocp::Registry

	class CloudManager

		class Openstack 

			module CinderHelper
				CINDER_QUOTA_FIELDS = ["volumes", "snapshots", "gigabytes"]

				def default_volume_quota
					with_openstack { 
						hash = volume.get_quota_defaults(nil).body["quota_set"] 
						Ocp::Registry::Common.hash_filter(hash, CinderHelper)
					}
				end

				def set_volume_quota(tenant_id, hash)
					with_openstack do 
						settings = Ocp::Registry::Common.hash_filter(hash, CINDER_QUOTA_FIELDS)
						volume.update_quota(tenant_id, settings).body["quota_set"]
					end
				end

			end

		end

	end

end
