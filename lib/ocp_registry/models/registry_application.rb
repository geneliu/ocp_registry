
module Ocp::Registry::Models
  class RegistryApplication < Sequel::Model
  	def before_create
  		values[:id] = Ocp::Registry::Common.uuid
  		values[:created_at] = Time.now.utc.to_s
  		values[:state] = 'PENDING'
  	end
  end
end