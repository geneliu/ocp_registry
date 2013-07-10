$:.unshift(File.join(File.dirname(__FILE__), 'lib'))
$:.unshift(File.dirname(__FILE__))

module Ocp
  module Registry
    autoload :Models, "ocp_registry/models"
  end
end

require "fog"
require "logger"
require "sequel"
require "sinatra/base"
require "thin"
require "yajl"
require "securerandom"
require "uri"

require "ocp_registry/yaml_helper"
require "ocp_registry/runner"
require "ocp_registry/error"
require "ocp_registry/config"
require "ocp_registry/application_manager"
require "ocp_registry/api_controller"
require "ocp_registry/common"


Sequel::Model.plugin :validation_helpers