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

		public

		def has_html_tag?(val)
			if !(val.is_a? String)
				return false
			end

			return true if val.include? ">"
			return true if val.include? "<"
			return false
		end

		def str_int?(val)
			ptn = /\A\d+\Z/
			val =~ ptn
		end

		def cidr_net_addr?(val)
			ptn = /\A\d{1,3}(\.\d{1,3}){3}\/\d{1,2}\Z/  # e.g. 192.168.255.12/24
			val =~ ptn
		end

		def ip_addr?(val)
			ptn = /\A\d{1,3}(\.\d{1,3}){3}\Z/	# e.g. 192.168.255.7
			val =~ ptn
		end

		def ip_range_per_line?(val)
			# e.g.
			# 192.168.255.1,192.168.255.100
			# 192.168.255.200,192.168.255.24
			# ...
			ptn = /\A\d{1,3}(\.\d{1,3}){3},\d{1,3}(\.\d{1,3}){3}(\n\d{1,3}(\.\d{1,3}){3},\d{1,3}(\.\d{1,3}){3})*\Z/
			val =~ ptn
		end

		def parse_ip_range_per_line(val)
			return nil if val.nil? || val=="" || val.strip.empty?
			ret = []
			val.split(/\n/).each do |token|
				ips = token.split(/,/)
				if ips.length < 2
					return nil
				end
				ret.push({:start => ips[0], :end => ips[1]})
			end
			return ret
		end

		def ip_addr_per_line?(val)
			ptn = /\A\d{1,3}(\.\d{1,3}){3}(\n\d{1,3}(\.\d{1,3}){3})*\Z/
			val =~ ptn
		end

		def parse_ip_addr_per_line(val)
			return nil if val.nil? || val=="" || val.strip.empty?
			return val.split(/\n/)
		end

	end
end