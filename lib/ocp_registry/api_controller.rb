
module Ocp::Registry

  class ApiController < Sinatra::Base

    set :root, File.join(File.dirname(__FILE__), '../../')

  	not_found do
      exception = request.env["sinatra.error"]
      @logger.debug(request.path_info)
      @logger.error(exception.message)
      do_response({:status => "not_found"}, nil)
    end

    error do
      exception = request.env["sinatra.error"]
      @logger.error(exception)
      status(500)
      do_response({:status => "error"}, nil)
    end

    error Ocp::Registry::Error do
      error = request.env["sinatra.error"]
      status(error.code)
      do_response({:status => "error", :message => error.message},nil)
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
      if email
  		  do_response(data, :list)
      else
        do_response(data, :list, :review => true)
      end
  	end

    get '/' do
      redirect to('/v1/applications/default')
    end

    # check project name 
    post '/v1/applications/check' do
      if project = params[:project] 
        result = @application_manager.existed_tenant?(project)
        do_response(!result, nil)
      end
    end

  	# get an application detail
  	get '/v1/applications/:id' do
      if(params[:id] == "default")
        do_response(@application_manager.default, :apply)
      else
    		application = @application_manager.show(params[:id])
        if("true" == params[:review])
          protected!
    		  do_response(application.to_hash(:lazy_load => false), :review)
        else
          do_response(application.to_hash(:lazy_load => false, :limit => 2), :view)
        end
      end
  	end

  	# create an application
  	post '/v1/applications' do
      app_info = Yajl.load(request.body.read)
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
  	  result = @application_manager.approve(params[:id])
      do_response(result.to_hash, nil)
  	end

  	# refuse an application
  	post '/v1/applications/:id/refuse' do
  	  protected!
  	  body = Yajl.load(request.body.read)
      comments = nil
      comments = body['comments'] if body && body['comments']
      result = @application_manager.refuse(params[:id], comments)
      do_response(result.to_hash, nil)
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
        json(data)
      else
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
