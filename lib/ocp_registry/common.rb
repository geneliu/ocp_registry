module Ocp::Registry::Common

	class << self

		def uuid
      SecureRandom.uuid
    end

    def gen_password
			SecureRandom.base64
		end

		def parse_email(email)
			return unless email =~ /[a-z0-9_.-]+@[a-z0-9-]+\.[a-z.]+/
				email =~ /([a-z0-9_.-]+)@([a-z0-9-]+\.[a-z.]+)/
				{
					:name => $1 ,
					:domain => $2
				}
		end

		def hash_filter(hash, fields = [])
			copy = deep_copy(hash)
			do_hash_filter(copy, fields)
		end

		def deep_copy(o)
  		Marshal.load(Marshal.dump(o))
		end

		private 

		def do_hash_filter(hash, fields = [])
			hash.keep_if do |k,v|
				if v.is_a? Hash
					do_hash_filter(v, fields)
					!v.empty?
				else
					fields.include? k
				end
			end
		end
	end
end