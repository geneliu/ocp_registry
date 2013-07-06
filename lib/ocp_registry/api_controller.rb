
module Ocp::Registry

  class ApiController < Sinatra::Base

  	not_found do
      exception = request.env["sinatra.error"]
      @logger.error(exception.message)
      do_response json(:status => "not_found")
    end

    error do
      exception = request.env["sinatra.error"]
      @logger.error(exception)
      status(500)
      do_response json(:status => "error")
    end

    error Ocp::Registry::Error do
      error = request.env["sinatra.error"]
      status(error.code)
      do_response json(:status => "error", :message => error.message)
    end

  	# get application list
  	get '/v1/applications' do
      email = params[:email]
      protected! unless email
      data = []

  		result = @application_manager.list(email)

      result.each do |app|
        data << app.to_hash
      end
  		do_response json(data)
  	end

    # check project name 
    post '/v1/applications/project_ok' do
      if project = params[:project] 
        result = @application_manager.existed_tenant?(project)
        do_response json(!result)
      end
    end

  	# get an application detail
  	get '/v1/applications/:id' do
      if(params[:id] == "default")
        do_response json(@application_manager.default)
      else
    		application = @application_manager.show(params[:id])
    		do_response json(application.to_hash)
      end
  	end

  	# create an application
  	post '/v1/applications' do
      app_info = Yajl.load(request.body.read)
      if app_info.kind_of?(Hash) && app_info['settings'].kind_of?(Hash)
        app_info[:settings] = json(app_info['settings']) 
      end
  		application = @application_manager.create(app_info)
      app_info = application.to_hash
  		do_response json(app_info)
  	end

  	# approve an application
  	post '/v1/applications/:id/approve' do
  	  protected!
  	  @application_manager.approve(params[:id])
      do_response json(:status => "ok")
  	end

  	# refuse an application
  	post '/v1/applications/:id/refuse' do
  	  protected!
  	  body = Yajl.load(request.body.read)
  	  @application_manager.refuse(params[:id],body['comments']||'')
      do_response json(:status => "ok")
  	end


  	def initialize
      super
      @logger = Ocp::Registry.logger
      @users = Set.new
      @users << [Ocp::Registry.http_user, Ocp::Registry.http_password]
      @application_manager = Ocp::Registry.application_manager
    end

    private

    def do_response(data)
      if request.accept? 'application/json'
        return data
      else
        return 'html'
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
