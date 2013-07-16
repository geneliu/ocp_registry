
module Ocp::Registry::Models
  class RegistryApplication < Sequel::Model
  	def before_create
  		values[:id] = Ocp::Registry::Common.uuid
  		values[:created_at] = Time.now.utc.to_s
  		values[:state] = 'PENDING'
  	end

  	one_to_many :registry_settings, :select => [:id ,:comments, :settings, :updated_at], :order => :version

  	def to_hash(opts = {})
  		hash = self.values
  		if false == opts[:lazy_load] && self.registry_settings
  			settings = []
  			self.registry_settings.each do |set|
  				settings << set.to_hash
  			end
  			hash[:registry_settings] = settings
  		end
  		hash
  	end

  end
end