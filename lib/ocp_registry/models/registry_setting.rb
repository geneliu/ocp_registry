module Ocp::Registry::Models
  class RegistrySetting < Sequel::Model
  	def before_create
  		values[:updated_at] = Time.now.utc.to_s
  	end
  end
end