
module Ocp::Registry

	class ApplicationManager

		def initialize(cloud_manager,mail_manager)
			@cloud_manager = cloud_manager
			@mail_manager = mail_manager
			@logger = Ocp::Registry.logger
		end

		def list(email=nil)
			if email
				results = Ocp::Registry::Models::RegistryApplication.reverse_order(:created_at).where(:email => email)
			else
				results = Ocp::Registry::Models::RegistryApplication.reverse_order(:created_at).all
			end
		
			results
		end

		def show(app_id)
			get_application(app_id)
		end

		def default
			{
				:email => "user@domain.com" ,
				:project => "your project name" ,
				:description => "short description of your project" ,
				:settings => @cloud_manager.default_quota
			}
		end

		def approve(app_id)
			app_info = get_application(app_id)

			# create project tenant and user
			tenant = @cloud_manager.create_tenant(app_info.project, app_info.description)

			@logger.info("Project [#{tenant.name}] - [#{tenant.id}] has been created with detail json - #{tenant.to_json}")

			password = Ocp::Registry::Common.gen_password
			username = Ocp::Registry::Common.parse_email(app_info.email)[:name]
			user = @cloud_manager.create_user(username, tenant.id, password, app_info.email)

			@logger.info("User [#{user.name}] - [#{user.id}] has been created with detail json - #{tenant.to_json}")
			@logger.debug("Password is #{password}")

			role = @cloud_manager.default_role

			@cloud_manager.tenant_add_user_with_role(tenant, user.id, role.id)

			@logger.info("User [#{user.name}] - [#{user.id}] has been added into project [#{tenant.name}] - [#{tenant.id}]")

			#assign quota to project

			settings = @cloud_manager.set_tenant_quota(tenant.id, Yajl.load(app_info.settings))

			Ocp::Registry::Models::RegistryApplication.where(:id => app_id)
																								.update(:state => 'APPROVED',
				                                                :updated_at => Time.now.utc.to_s,
				                                                :settings => Yajl::Encoder.encode(settings) )
			if @mail_manager
				@mail_manager.send_mail(info,:approve)
			end
		end

		def refuse(app_id,comments)
			Ocp::Registry::Models::RegistryApplication.where(:id => app_id)
																								.update(:state => 'REFUSED',
																												:updated_at => Time.now.utc.to_s,
																												:comments => comments)
			if @mail_manager
				@mail_manager.send_mail(info,:refuse)
			end
		end

		def create(app_info)
			if existed_tenant?(app_info['project'])
				{:message => 'project name has been used'}
			else
				result = {}
		 		result = Ocp::Registry::Models::RegistryApplication.create(app_info)
				if @mail_manager
					@mail_manager.send_mail(info,:pending)
				end
				result
			end
		end

		def existed_tenant?(tenant)
		  return @cloud_manager.get_tenant_by_name(tenant)? true : false
		end

		private 

		def get_application(app_id)
			Ocp::Registry::Models::RegistryApplication[:id => app_id]
		end

	end

end