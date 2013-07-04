
module Ocp::Registry

	class ApplicationManager

		def initialize(cloud_manager,mail_manager)
			@cloud_manager = cloud_manager
			@mail_manager = mail_manager
			@logger = Ocp::Registry.logger
		end

		def list(email=nil)
			data = []
			if email
				result = Ocp::Registry::Models::RegistryApplication.reverse_order(:created_at).where(:email => email)
			else
				result = Ocp::Registry::Models::RegistryApplication.reverse_order(:created_at).all
			end
			
			result.each do |app|
				@logger.debug(app.to_hash)
				data << app.to_hash
			end

			data

		end

		def show(app_id)
			result = {}
			result = Ocp::Registry::Models::RegistryApplication[:id => app_id]
			result.to_hash
		end

		def approve(app_id)
			tenant = @cloud_manager.create_tenant
			user = @cloud_manager.create_user
			@cloud_manager.add_user_to_tenant(tenant, user)
			Ocp::Registry::Models::RegistryApplication.where(:id => app_id)
																								.update(:state => 'APPROVED',
				                                                :updated_at => Time.now.utc.to_s)
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
			result = {}
			app_info.merge! ({:created_at => Time.now.utc.to_s})
	 		result = Ocp::Registry::Models::RegistryApplication.create(app_info)
			if @mail_manager
				@mail_manager.send_mail(info,:pending)
			end
			result.to_hash
		end

	end

end