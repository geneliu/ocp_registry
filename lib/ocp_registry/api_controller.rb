
module Ocp::Registry

  class ApiController < Sinatra::Base

	not_found do
    exception = request.env["sinatra.error"]
    @logger.error(exception.message)
    json(:status => "not_found")
  end

  error do
    exception = request.env["sinatra.error"]
    @logger.error(exception)
    status(500)
    json(:status => "error")
  end

	# get application list
	get '/v1/applications' do

		@application_manager.list

	end


	# get an application details
	get '/v1/applications/:id' do
		application = @application_manager.show(params[:id])
		json(application)
	end

	# create an application
	post '/v1/applications' do
		application = @application_manager.create(Yajl.load(request.body.read))
		json(application)
	end

	# approve an application
	post '/v1/applications/:id/approve' do
	  protected!
	  @application_manager.approve(params[:id])
	end

	# refuse an application
	post '/v1/applications/:id/refuse' do
	  protected!
	  body = Yajl.load(request.body.read)
	  @application_manager.refuse(params[:id],body[:comment]||'')
	end


	def initialize
      super
      @logger = Ocp::Registry.logger
      @users = Set.new
      @users << [Ocp::Registry.http_user, Ocp::Registry.http_password]
      @application_manager = Ocp::Registry.application_manager
  end

  def protected!
    unless authorized?
      headers("WWW-Authenticate" => 'Basic realm="OCP Registry"')
      halt(401, json("status" => "access_denied"))
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
