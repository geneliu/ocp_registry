
module Ocp::Registry

  class ApiController < Sinatra::Base

    set :root, File.join(File.dirname(__FILE__), '../../')

  	not_found do
      exception = request.env["sinatra.error"]
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")
      @logger.info(exception.message)
      do_response({:status => "not_found"}, nil)
    end

    error do
      exception = request.env["sinatra.error"]
      @logger.info(exception)
      status(500)
      do_response({:status => "error"}, nil)
    end

    error Ocp::Registry::Error do
      error = request.env["sinatra.error"]
      @logger.info(error.message)
      status(error.code)
      do_response({:status => "error", :message => error.message},nil)
    end

  	# get application list
  	get '/v1/applications' do
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")
      email = params[:email]
      protected! unless email
      if email
        data = {:status => "error", :message => "Sorry, list all applications of a specific user is not supported any more since security risks"}
  		  do_response(data)
      else
        data = []
        result = @application_manager.list
        result.each do |app|
          data << app.to_hash
        end
        do_response(data, :list, :review => true)
      end
  	end

    get '/' do
      redirect to('/v1/applications/default')
    end

    # check project name 
    post '/v1/applications/check' do
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")
      if project = params[:project] 
        result = @application_manager.existed_tenant?(project)
        do_response(!result, nil)
      end
    end

  	# get an application detail
  	get '/v1/applications/:id' do
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")
      if(params[:id] == "default")
        do_response(@application_manager.default, :apply)
      else
    		application = @application_manager.show(params[:id])
        if("true" == params[:review])
          protected!
          if "true" == params[:modified]
      		  data = application.to_hash(:lazy_load => false, :limit => 2)
            view = :admin_modify
          else
            data = application.to_hash(:lazy_load => false, :limit => 1)
            view = :review
          end
        else
          if "true" == params[:modified]
            data = application.to_hash(:lazy_load => false, :limit => 2)
            view = :user_modify
          else
            data = application.to_hash(:lazy_load => false, :limit => 1)
            view = :view
          end
        end
        do_response(data,view)
      end
  	end

  	# create an application
  	post '/v1/applications' do
      app_info = Yajl.load(request.body.read)

      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip} : #{app_info}")

      if app_info.kind_of?(Hash) && app_info['settings'].kind_of?(Hash)
        default = Yajl::load(@application_manager.default[:registry_settings].first[:settings])
        settings = default.merge(app_info['settings'])
        app_info["settings"] = json(settings)
      end
  		application = @application_manager.create(app_info)
      app_info = application.to_hash
  		do_response(app_info, nil)
  	end

  	# approve an application
  	post '/v1/applications/:id/approve' do
  	  protected!
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")
  	  result = @application_manager.approve(params[:id])
      do_response(result.to_hash, nil)
  	end

  	# refuse an application
  	post '/v1/applications/:id/refuse' do
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")

  	  protected!
  	  body = Yajl.load(request.body.read)
      comments = nil
      comments = body['comments'] if body && body['comments']
      result = @application_manager.refuse(params[:id], comments)
      do_response(result.to_hash, nil)
  	end

    post '/v1/applications/:id/settings' do
      setting = Yajl.load(request.body.read)
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip} : #{setting}")

      if setting["from"] && setting["from"].strip.upcase == "ADMIN"
        protected! 
        setting["from"] = "ADMIN"
      else
        setting["from"] = "USER"
      end
      result = @application_manager.add_setting_for(params[:id],setting)
      do_response(result.to_hash)
    end

    get '/v1/applications/:id/settings' do
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")

      result = @application_manager.list_settings(params[:id])

      data = []
      result.each do |setting|
        data << setting.to_hash
      end

      do_response(data)
    end

    post '/v1/applications/:id/cancel' do
      @logger.info("[RECEIVED] #{request.request_method} : #{request.url} - #{request.ip}")

      result = @application_manager.cancel(params[:id])
      do_response(result.to_hash)
    end

  	def initialize
      super
      @logger = Ocp::Registry.logger
      @users = Set.new
      @users << [Ocp::Registry.http_user, Ocp::Registry.http_password]
      @application_manager = Ocp::Registry.application_manager
    end

    private

    def do_response(data, view = nil, mark = nil)
      if request.accept?('application/json') || view.nil? || (data.is_a?(Hash)&&'error' == data[:status])
        @logger.info("[RESPONSE] JSON : json - #{data}")
        json(data)
      else
        @logger.info("[RESPONSE] VIEW : #{view.to_s} - #{data}")
        erb :base do 
          erb view ,:locals => {:data => data ,:mark => mark}
        end
      end

    end

    def protected!
      unless authorized?
        headers("WWW-Authenticate" => 'Basic realm="OCP Registry"')
        halt(401, json("message" => "access_denied"))
      end
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? &&
        @auth.basic? &&
        @auth.credentials &&
        @users.include?(@auth.credentials)
    end

    def json(payload)
      Yajl::Encoder.encode(payload)
    end

  end
end
