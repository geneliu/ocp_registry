module Ocp::Registry::Common

		EMAIL_REGEX = /[a-z0-9_.-]+@[a-z0-9-]+\.[a-z.]+/

	class << self

		def uuid
      SecureRandom.uuid
    end

    def gen_password
			SecureRandom.base64
		end

		def parse_email(email)
			return unless email =~ EMAIL_REGEX
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

		def json_merge(a,b,reverse = false)
			hash_a = Yajl::load a 
			hash_b = Yajl::load b
			if reverse
				b.merge a
			else
				a.merge b
			end
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