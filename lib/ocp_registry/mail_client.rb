module Ocp::Registry
	class MailClient

		require "net/smtp"
		require "thread"

		DEFAULT_WORKER = 1
		DEFAULT_PORT = '25'
		DEFAULT_HELO = 'ocp.com'
		TEMPLATES_PATH = File.join(File.dirname(__FILE__),'../../mail_template')
		DEFAULT_FROM = 'registry@ocp.com'
		DEFAULT_TLS = false
		DEFAULT_ADMIN_EMAIL = 'admin@ocp.com'

		def initialize(mail_config)
			validate_opinions(mail_config)

			@logger = Ocp::Registry.logger

			@worker = mail_config["worker"] || DEFAULT_WORKER
			@enable_tls = mail_config["enable_tls"] || DEFAULT_TLS

			@mail_opinions = {
				:address => mail_config["smtp_server"] ,
				:port => mail_config["port"] || DEFAULT_PORT ,
				:helo => mail_config["helo"] || DEFAULT_HELO ,
				:user => mail_config["username"] || nil ,
				:secret  => mail_config["password"] || nil ,
				:authtype  => mail_config["authentication"] || nil
			}

			@admin_emails = mail_config["admin_emails"] || DEFAULT_ADMIN_EMAIL

			@mail_queue = Queue.new

			setup_senders

		end

		def admin_emails
			@admin_emails
		end

		def send_mail(mail_info)
			mail_info.merge!({ :from => DEFAULT_FROM }) 
			@mail_queue << mail_info if mail_validated?(mail_info)
		end

		def validate_opinions(mail_config)
			unless mail_config["smtp_server"] && mail_config["admin_emails"]
				raise ConfigError, "Invalid Mail configuration"
			end
		end

		def mail_validated?(mail_info)
			unless mail_info[:from] && mail_info[:to] && mail_info[:template] && has_template?(mail_info[:template])
				@logger.warning "Mail is ignored because less of necessary fields "
				return false
			end
				true
		end

		def has_template?(template)
			File.exists? File.expand_path("#{TEMPLATES_PATH}/#{template}.erb")
		end

		def prepare_message(mail)
			template = mail.delete(:template)
			template = File.read(File.expand_path("#{TEMPLATES_PATH}/#{template}.erb"))
			@logger.debug "Starting prepare message for mail - #{mail.to_s}"
			begin
				info = mail[:msg]
				message = ERB.new(template).result binding
			rescue Exception => e
				@logger.error "Load email template failed - #{e.message}"
				@logger.debug(e.backtrace.join("\n"))
			end
			return message ,  mail[:from] , mail[:to] 
		end

		private 

		# Here we use multi-thread to realize a provider-consumer mode with a block-queue
		# TODO: Realize with Fiber 
		def setup_senders
			@worker.times do |index|

				thread = Thread.new { create_sender }
				thread.run

				@logger.info("Mail sender thread #{index} is running ")

			end

		end


		def create_sender
			loop do
				mail = @mail_queue.pop
				begin
					if @enable_tls
						require "tlsmail"
						Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
					end
					@logger.info("Starting SMTP with opinions #{@mail_opinions}")
					Net::SMTP.start(@mail_opinions[:address] ,
													@mail_opinions[:port] ,
													@mail_opinions[:helo] ,
													@mail_opinions[:user] ,
													@mail_opinions[:secret] ,
													@mail_opinions[:authtype]) do |smtp|
						until mail.nil? do 
							msg, from, to  = prepare_message(mail)
							smtp.send_message(msg, from, to)
							@logger.debug("Mail is sent with message \n#{msg}")
							begin
								mail = @mail_queue.pop(:non_block => true )
							rescue ThreadError => e
								mail = nil 
							end
						end
					end
				rescue Net::SMTPAuthenticationError => e
					@logger.error("Mail server authentication failed - #{e.message}", e)
					@logger.debug(e.backtrace.join("\n"))
				rescue Net::SMTPError => e
					@logger.error("Mail is not sent because of SMTP error - #{e.message}")
					@logger.debug(e.backtrace.join("\n"))
				rescue Exception => e
					@logger.error(e.message)
					@logger.debug(e.backtrace.join("\n"))
				end
			end
		end




	end
end