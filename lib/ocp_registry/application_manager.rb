
module Ocp::Registry

	class ApplicationManager

		def initialize(cloud_manager,mail_manager)
			@cloud_manager = cloud_manager
			@mail_manager = mail_manager
			@logger = Ocp::Registry.logger
		end

		def list(email = nil)
			if email
				results = Ocp::Registry::Models::RegistryApplication.reverse_order(:created_at).where(:email => email)
				@logger.debug("List applications for user - #{email}")
			else
				results = Ocp::Registry::Models::RegistryApplication.reverse_order(:created_at).all
				@logger.debug("List applications for ADMIN")
			end
			results
		end

		def cancel(app_id)
			app_info = get_application(app_id)
			valid , message = application_valid? app_info
			return message unless valid
			
			Ocp::Registry::Models::RegistryApplication.where(:id => app_id).update(:state => 'CANCELED', :end_at => Time.now.utc.to_s)
			app_info = get_application(app_id)
			@logger.debug("[CANCELED] project [#{app_info.project}] - [#{app_info.id}] at [#{app_info.end_at}]")

			if @mail_manager
				admin_msg = {
					:app_info => app_info
				}
				mail = prepare_mail_properties(:cancel_admin, @mail_manager.admin_emails, admin_msg)
				@mail_manager.send_mail(mail)
				user_msg = {
					:app_info => app_info
				}
				mail = prepare_mail_properties(:cancel_user, app_info.email, user_msg)
				@mail_manager.send_mail(mail)
			end

			app_info
		end

		def list_settings(app_id)
			Ocp::Registry::Models::RegistrySetting.reverse_order(:version).where(:registry_application_id => app_id)
		end

		def show(app_id)
			app_info = get_application(app_id)
			return {:status => "error", :message => "Application with id - [#{app_id}] is not existed"} if app_info.nil?
			app_info
		end

		def add_setting_for(app_id, setting)
			app_info = get_application(app_id)
			valid , message = application_valid? app_info
			return message unless valid

			last_setting = Ocp::Registry::Models::RegistrySetting.where(:registry_application_id => app_id).order_by(:version).last
																													 
			if last_setting.from == setting["from"]
				wait_for = setting["from"] == "ADMIN" ?  app_info.email : "Administrator"
				return {:status => "error", :message => "Please wait for #{wait_for} review your last updates at #{last_setting.updated_at}"}
			end

			change_set = []
			if setting && setting["settings"]
				src = Yajl::load(last_setting.settings)
				dest = setting["settings"]
				
				valid, message = setting_valid? dest
				return message unless valid
				
				merged = src.merge(dest) do |key, v1, v2|
					if v1 != v2 
						change = {
							:key => key,
							:from => v1,
							:to => v2
						}
						change_set << change
					end
					v2
				end
				return {:status => "error", :message => "No changes in settings are found"} if change_set.empty?

				set = Yajl::Encoder.encode(merged)
				comments = "#{setting["comments"]}" if setting["comments"]				

				@logger.info("Project [#{app_info.project}] - [#{app_info.id}] setting changed : #{change_set}")
			else
				set = last_setting.settings
				comments = "ACCEPT"
				comments += " - #{setting["comments"]}" if setting["comments"]

				@logger.info("Project [#{app_info.project}] - [#{app_info.id}] setting accepted : #{set}")
			end


			update_time = Time.now.utc.to_s
			last_setting.comments = comments
			last_setting.updated_at = update_time
			last_setting.save_changes

			@logger.debug("Project [#{app_info.project}] - [#{app_info.id}] setting [#{last_setting.id}] comments - [#{comments}]")

			new_setting = Ocp::Registry::Models::RegistrySetting.new(:registry_application_id => app_id,
																		:updated_at => update_time,
																		:settings => set,
																		:version => (last_setting.version + 1),
																		:from => setting["from"])
			new_setting.save

			@logger.info("Project [#{app_info.project}] - [#{app_info.id}] current setting is #{new_setting.id} - #{new_setting.settings}")

			if @mail_manager
				if setting["from"] == "ADMIN"
					link = gen_app_uri(app_id, :modified => true)
					mail_to = app_info.email
				else
					link = gen_app_uri(app_id, :modified => true, :review => true)
					mail_to = @mail_manager.admin_emails
				end

				msg = {
					:from => setting["from"] == "ADMIN" ? "Administrator" : app_info.email ,
					:name => setting["from"] == "ADMIN" ?  "User from #{app_info.email}" : "Administrator" ,
					:change_set => change_set ,
					:app_info => app_info ,
					:comments => comments , 
					:time => update_time ,
					:application_link => link
				}
 
				mail = prepare_mail_properties(:modify, mail_to, msg)
				@mail_manager.send_mail(mail)	
			end

			app_info
		end

		def default 
			return @default if @default

			settings = Yajl::Encoder.encode(@cloud_manager.default_quota)
			default_setting = {
				:settings => settings
			}
			registry_settings = [] << default_setting

			@default = {
				:email => "" ,
				:project => "" ,
				:description => "" ,
				:registry_settings => registry_settings
			}

		end

		def create_tenant(name, description)
			tenant = @cloud_manager.create_tenant(name, description)
			@logger.info("Project [#{tenant.name}] - [#{tenant.id}] has been created with detailed json - #{tenant.to_json}")
			return tenant
		end

		def create_user(tenant, email)
			username = Ocp::Registry::Common.parse_email(email)[:name]
			user = @cloud_manager.find_user_by_name(username)
			if user.nil?
				password = Ocp::Registry::Common.gen_password
				user = @cloud_manager.create_user(username, tenant.id, password, email)
				@logger.info("User [#{user.name}] - [#{user.id}] has been created with detailed json - #{user.to_json}")
			else
				password = "<your-password-in-previous-project>"
				@logger.info("Using existed User [#{user.name}] - [#{user.id}] with detailed json - #{user.to_json}")
			end
			return user
		end

		def assign_user_to_tenant(tenant, user)
			role = @cloud_manager.default_role
			@cloud_manager.tenant_add_user_with_role(tenant, user.id, role.id)
			@logger.info("User [#{user.name}] - [#{user.id}] has been added into 
										project [#{tenant.name}] - [#{tenant.id}] as [#{role.name}] - [#{role.id}]")
		end

		def set_quota_for_tenant(tenant, last_settings)
			settings = @cloud_manager.set_tenant_quota(tenant.id, Yajl.load(last_settings))
			@logger.info("Quota for project [#{tenant.name}] - [#{tenant.id}] has been
									 set as json - #{last_settings}")
		end

		def create_tenant_network(tenant, last_settings)
			network = @cloud_manager.create_tenant_network(tenant.id, Yajl.load(last_settings))
			@logger.info("Network for project [#{tenant.name}] - [#{tenant.id}] has been created #{network}")
		end

		def set_application_status(status, app_info, current_setting=nil, comments=nil)
			time = Time.now.utc.to_s
			app_info.state = status
			app_info.end_at = time
			app_info.save_changes

			unless current_setting.nil?
				current_setting.updated_at = time
				unless comments.nil?
					current_setting.comments = "#{status}  #{comments}"
				end
				current_setting.save_changes
			end

			@logger.info("Project [#{app_info.project}] - [#{app_info.id}] has been [#{status}] at #{time}")
		end

		def approve(app_id)
			app_info = get_application(app_id)
			valid, message = application_valid? app_info
			return message unless valid

			set_application_status('APPROVED', app_info)
			begin
				# TODO post remedy ticket here
				ticket = "<Hi, I'm remedy ticket address>"
				app_info.ticket = ticket
				app_info.save_changes

				if @mail_manager
					admin_msg = {
						:app_info => app_info,
						:ticket => ticket,
						:application_link => gen_app_uri(app_id, :deploy => true),
						:applications_link => gen_app_uri
					}
					mail = prepare_mail_properties(:approve_admin, @mail_manager.admin_emails, admin_msg)
					@mail_manager.send_mail(mail)

					user_msg = {
						:app_info => app_info,
						:application_link => gen_app_uri(app_id),
					}
					mail = prepare_mail_properties(:approve_user, app_info.email, user_msg)
					@mail_manager.send_mail(mail)
				end
			rescue Exception => e
				@logger.error "Failed to apply remedy ticket for network resource - #{e.message}, app_id = #{app_id}"
				@logger.debug(e.backtrace.join("\n"))

				if @mail_manager
					admin_msg = {
						:app_info => app_info,
						:application_link => gen_app_uri(app_id),
						:applications_link => gen_app_uri
					}
					mail = prepare_mail_properties(:ticket_error_admin, @mail_manager.admin_emails, admin_msg)
					@mail_manager.send_mail(mail)
				end
			end
			app_info
		end

		def deploy(app_id, setting)
			# check deployable
			app_info = get_application(app_id)
			valid, message = application_deployable? app_info
			return message unless valid

			# check settings valid
			valid, message = setting_valid? setting
			return message unless valid

			# save new settings
			last_setting = Ocp::Registry::Models::RegistrySetting.where(:registry_application_id => app_id).order_by(:version).last
			last_setting.updated_at = Time.now.utc.to_s
			last_setting.save_changes

			new_setting = Ocp::Registry::Models::RegistrySetting.new(:registry_application_id => app_id,
																		:updated_at => Time.now.utc.to_s,
																		:settings => Yajl::Encoder.encode(setting),
																		:version => (last_setting.version + 1),
																		:from => "ADMIN")
			new_setting.save
			@logger.info("Project [#{app_info.project}] - [#{app_info.id}] current setting is #{new_setting.id} - #{new_setting.settings}")

			if existed_tenant?(app_info.project, :find_local => false)
				@logger.info("Project [#{app_info.project}] name has been used during request time")
				refuse(app_info.id,"Project Name [#{app_info.project}] has been used during request time")
			end

			begin
				current_setting = new_setting
				set_application_status('DEPLOYING', app_info)

				# create project tenant and user
				tenant = create_tenant(app_info.project, app_info.description)
				user = create_user(tenant, app_info.email)
				puts "User created: #{user.inspect}"   # TODO debug
				assign_user_to_tenant(tenant, user)
				set_quota_for_tenant(tenant, current_setting.settings)
				create_tenant_network(tenant, current_setting.settings)

				set_application_status('DEPLOY_SUCC', app_info)
				
				if @mail_manager
					admin_msg = {
						:app_info => app_info,
						:username => user.name,
						:application_link => gen_app_uri(app_id),
						:applications_link => gen_app_uri
					}
					mail = prepare_mail_properties(:deploy_succ_admin, @mail_manager.admin_emails, admin_msg)
					@mail_manager.send_mail(mail)

					user_msg = {
						:app_info => app_info,
						:application_link => gen_app_uri(app_id),
						:login => Ocp::Registry.cloud_login_url,
						:username => user.name,
						:password => user.password
					}
					mail = prepare_mail_properties(:deploy_succ_user, app_info.email, user_msg)
					@mail_manager.send_mail(mail)
				end
				return app_info
			rescue Exception => e
				@logger.error "Deploy failed - #{e.message}, app_id = #{app_id}"
				@logger.debug(e.backtrace.join("\n"))

				set_application_status('DEPLOY_ERROR', app_info)
				if @mail_manager
					admin_msg = {
						:app_info => app_info,
						:application_link => gen_app_uri(app_id),
						:applications_link => gen_app_uri
					}
					mail = prepare_mail_properties(:deploy_error_admin, @mail_manager.admin_emails, admin_msg)
					@mail_manager.send_mail(mail)

					user_msg = {
						:app_info => app_info,
						:application_link => gen_app_uri(app_id),
					}
					mail = prepare_mail_properties(:deploy_error_user, app_info.email, user_msg)
					@mail_manager.send_mail(mail)
				end
				return {:status => "error", :message => "Application [#{app_info.project}] - #{app_info.id} deploy failed"} 
			end
		end

		def refuse(app_id, comments)
			app_info = get_application(app_id)
			valid , message = application_valid? app_info
			return message unless valid

			#update application status
			current_setting = app_info.registry_settings_dataset.order_by(:version).last
			set_application_status('REFUSED', app_info, current_setting, comments)

			app_info = get_application(app_id)

			if @mail_manager
				admin_msg = {
					:app_info => app_info , 
					:comments => current_setting.comments ,
					:application_link => gen_app_uri(app_id, :review => true) ,
					:applications_link => gen_app_uri
				}
				mail = prepare_mail_properties(:refuse_admin, @mail_manager.admin_emails, admin_msg)
				@mail_manager.send_mail(mail)
				user_msg = {
					:app_info => app_info , 
					:comments => current_setting.comments ,
					:application_link => gen_app_uri(app_id) ,
				}
				mail = prepare_mail_properties(:refuse_user, app_info.email, user_msg)
				@mail_manager.send_mail(mail)
			end
			app_info
		end

		def create(app_info)
			if existed_tenant?(app_info['project'])
				return {:status => "error", :message => "Project name [#{app_info['project']}] has been used"}
			else
				setting = app_info.delete("settings")
				valid, message = setting_valid? setting
				return message unless valid

		 		result = Ocp::Registry::Models::RegistryApplication.create(app_info)
		 		result.add_registry_setting(:settings => setting)

				@logger.info("Project [#{result.project}] - [#{result.id}] is [CREATED] - setting : #{setting}")

				if @mail_manager
					admin_msg = {
						:app_info => result , 
						:application_link => gen_app_uri(result.id, :review => true) ,
						:applications_link => gen_app_uri 
					}
					mail = prepare_mail_properties(:request_admin, @mail_manager.admin_emails, admin_msg)
					@mail_manager.send_mail(mail)
					user_msg = {
						:app_info => result ,
						:application_link => gen_app_uri(result.id) ,
					}
					mail = prepare_mail_properties(:request_user, result.email, user_msg)
					@mail_manager.send_mail(mail)
				end
				result
			end
		end

		def existed_tenant?(tenant, find_local = true)
			if find_local
				local_existed = Ocp::Registry::Models::RegistryApplication.where(:project => tenant, :state => 'APPROVED')
																																	.count == 0? false : true
				return true if local_existed
			end
		  remote_existed = @cloud_manager.get_tenant_by_name(tenant)? true : false
		  return remote_existed
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

		def gen_app_uri(app_id = nil, querys = nil)
			host = URI::escape(Ocp::Registry.base_url)
			port = Ocp::Registry.http_port
			path = "/v1/applications"
			if app_id
				path += URI::escape("/#{app_id}")
			end
			query = nil
			if(querys && querys.is_a?(Hash))
				querys.each do |key, value|
					if query.nil?
						query = "#{key.to_s}=#{value}"
					else
						query += "&" 
						query += "#{key.to_s}=#{value}"
					end
				end
			end

			uri = URI::HTTP.build(:host => host, :port => port, :path => path, :query => query).to_s
		end

		def application_valid?(app_info)
			if app_info.nil?
				return false , {:status => "error", :message => "Application with id - [#{app_info.id}] is not existed"}
			end
			unless app_info.state == 'PENDING'
				return false , {:status => "error", :message => "Application [#{app_info.project}] - #{app_info.id} has been #{app_info.state}"} 
			end
			return true
		end

		def application_deployable?(app_info)
			if app_info.nil?
				return false , {:status => "error", :message => "Application with id - [#{app_info.id}] is not existed"}
			end
			unless app_info.state == 'APPROVED'
				return false , {:status => "error", :message => "Application [#{app_info.project}] - #{app_info.id} has been #{app_info.state}"} 
			end
			return true
		end

		def setting_valid?(setting)
			if setting.is_a? String
				setting = Yajl::load(setting)
			end

			be_int = ["metadata_items",
									"cores",
									"instances",
									"injected_files",
									"injected_file_content_bytes",
									"ram", 
									"network", 
									"router",
									"port",
									"subnet",
									"floatingip",
									"security_group",
									"security_group_rule",
									"vlan_id"]
			can_be_empty = ["network_name", 
									"subnet_name", 
									"network_address", 
									"gateway_ip", 
									"allocation_pools", 
									"dns_name_servers",
									"vlan_id"]
			greater_than_or_equal_to_zero = ["metadata_items",
									"cores",
									"instances",
									"injected_files",
									"injected_file_content_bytes",
									"ram", 
									"network", 
									"router",
									"port",
									"subnet",
									"floatingip",
									"security_group",
									"security_group_rule",
									"vlan_id"]
			less_than_or_equal_to_1024 = ["cores",
									"instances",
									"network", 
									"router",
									"subnet",
									"floatingip"]
			
			cidr_net_addr = ["network_address"]
			ip_addr = ["gateway_ip"]
			ip_range_per_line = ["allocation_pools"]
			ip_addr_per_line = ["dns_name_servers"]

			invalid_field = nil
			setting.each do |k, v|
				invalid_field = k
				if !(v.is_a? String)
					break
				elsif (can_be_empty.include? k) && v==""
					# do nothing
				elsif Ocp::Registry::Common.has_html_tag? v
					break
				elsif (be_int.include? k) && !(Ocp::Registry::Common.str_int? v)
					break
				elsif (greater_than_or_equal_to_zero.include? k) && !(v.to_i >= 0)
					break
				elsif (less_than_or_equal_to_1024.include? k) && !(v.to_i <= 1024)
					break
				elsif (cidr_net_addr.include? k) && !(Ocp::Registry::Common.cidr_net_addr? v)
					break
				elsif (ip_addr.include? k) && !(Ocp::Registry::Common.ip_addr? v)
					break
				elsif (ip_range_per_line.include? k) && !(Ocp::Registry::Common.ip_range_per_line? v)
					break
				elsif (ip_addr_per_line.include? k) && !(Ocp::Registry::Common.ip_addr_per_line? v)
					break
				else
					# do nothing
				end
					invalid_field = nil
			end

			if invalid_field
				return false, {:status => "error", :message => "The setting contains invalid field - #{invalid_field}"}
			else
				return true
			end
		end
		
	end

end
