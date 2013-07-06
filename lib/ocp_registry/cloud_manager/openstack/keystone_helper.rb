module Ocp::Registry

	class CloudManager

		class Openstack

			module KeystoneHelper
		 		#{ 
	      #  "name": "ACME corp",
	      #  "description": "A description ...",
	      #  "enabled": true
	      #}
	      def create_tenant(name, description, enabled = true)
	      	with_openstack do 
	        	keystone.tenants.create( :name => name ,
	        														:description => description ,
	        														:enabled => enabled )
	      	end
	      end

	      #{
	      #  "username": "jqsmith",
	      #  "email": "john.smith@example.org",
	      #  "enabled": true,
	      #  "OS-KSADM:password": "secrete"
	      #}
	      def create_user(name, tenant_id, password, email = '')
	      	with_openstack do 
		        keystone.users.create( :name => name,
		        												:tenant_id => tenant_id,
		        												:password => password,
		        												:email => email)
	      	end
	      end

	      def get_tenant_by_name(name)
	      	with_openstack { keystone.tenants.find {|tenant| tenant.name == name} }
	      end

	      def tenant_add_user_with_role(tenant, user_id, role_id)
	        with_openstack { tenant.grant_user_role(user_id, role_id) }
	      end

	      def get_role_by_name(name)
	      	with_openstack { keystone.roles.find {|role| role.name == name} }
	      end
			end

		end

	end

end
