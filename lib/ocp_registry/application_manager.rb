
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

			unless existed_tenant?(app_info.project) then
				# create project tenant and user
				tenant = @cloud_manager.create_tenant(app_info.project, app_info.description)

				@logger.info("Project [#{tenant.name}] - [#{tenant.id}] has been created with detailed json - #{tenant.to_json}")

				password = Ocp::Registry::Common.gen_password
				username = Ocp::Registry::Common.parse_email(app_info.email)[:name]

				user = @cloud_manager.find_user_by_name(username)

				if user.nil?
					user = @cloud_manager.create_user(username, tenant.id, password, app_info.email)
					@logger.info("User [#{user.name}] - [#{user.id}] has been created with detailed json - #{tenant.to_json}")
				else
					@logger.info("Using existed User [#{user.name}] - [#{user.id}] with detailed json - #{tenant.to_json}")
				end

				role = @cloud_manager.default_role

				@cloud_manager.tenant_add_user_with_role(tenant, user.id, role.id)

				@logger.info("User [#{user.name}] - [#{user.id}] has been added into project [#{tenant.name}] - [#{tenant.id}] as [#{role.name}] - [#{role.id}]")

				#assign quota to project

				settings = @cloud_manager.set_tenant_quota(tenant.id, Yajl.load(app_info.settings))

				Ocp::Registry::Models::RegistryApplication.where(:id => app_id)
																									.update(:state => 'APPROVED',
					                                                :updated_at => Time.now.utc.to_s,
					                                                :settings => Yajl::Encoder.encode(settings) )
				if @mail_manager
					admin_msg = {
						:app_info => app_info , 
						:application_link => gen_app_uri(app_id) ,
						:applications_link => gen_app_uri
					}
					mail = prepare_mail_properties(:approve_admin, @mail_manager.admin_emails, admin_msg)
					@mail_manager.send_mail(mail)
					user_msg = {
						:app_info => app_info ,
						:application_link => gen_app_uri(app_id) ,
						:applications_link => gen_app_uri(nil, app_info.email) ,
						:login => Ocp::Registry.cloud_login_url ,
						:username => username ,
						:password => password
					}
					mail = prepare_mail_properties(:approve_user, app_info.email, user_msg)
					@mail_manager.send_mail(mail)
				end
			else
				@logger.info("Project [#{tenant.name}] - [#{tenant.id}] name has been used during request time")
				refuse(app_info.id,"Project Name has been used during request time")
			end

		end

		def refuse(app_id,comments)
			Ocp::Registry::Models::RegistryApplication.where(:id => app_id)
																								.update(:state => 'REFUSED',
																												:updated_at => Time.now.utc.to_s,
																												:comments => comments)
			app_info = get_application(app_id)
			if @mail_manager
				admin_msg = {
					:app_info => app_info , 
					:application_link => gen_app_uri(app_id) ,
					:applications_link => gen_app_uri 
				}
				mail = prepare_mail_properties(:refuse_admin, @mail_manager.admin_emails, admin_msg)
				@mail_manager.send_mail(mail)
				user_msg = {
					:app_info => app_info , 
					:application_link => gen_app_uri(app_id) ,
					:applications_link => gen_app_uri(nil, app_info.email) 
				}
				mail = prepare_mail_properties(:refuse_user, app_info.email, user_msg)
				@mail_manager.send_mail(mail)
			end
		end

		def create(app_info)
			if existed_tenant?(app_info['project'])
				{:message => 'project name has been used'}
			else
		 		result = Ocp::Registry::Models::RegistryApplication.create(app_info)
				if @mail_manager
					admin_msg = {
						:app_info => result , 
						:application_link => gen_app_uri(result.id) ,
						:applications_link => gen_app_uri 
					}
					mail = prepare_mail_properties(:request_admin, @mail_manager.admin_emails, admin_msg)
					@mail_manager.send_mail(mail)
					user_msg = {
						:app_info => result ,
						:application_link => gen_app_uri(result.id) ,
						:applications_link => gen_app_uri(nil, result.email) 
					}
					mail = prepare_mail_properties(:request_user, result.email, user_msg)
					@mail_manager.send_mail(mail)
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

		def prepare_mail_properties(template, to, msg = {})
			{
				:to => to ,
				:template => template.to_s ,
				:msg => msg
			}
		end

		def gen_app_uri(app_id = nil, email = nil)
			host = URI::escape(Ocp::Registry.base_url)
			port = Ocp::Registry.http_port
			path = "/applications"
			if app_id
				path += URI::escape("/#{app_id}")
				@logger.info(path)
			end
			query = URI::escape("email=#{email}") if email

			uri = URI::HTTP.build(:host => host, :port => port, :path => path, :query => query).to_s
		end

	end

end