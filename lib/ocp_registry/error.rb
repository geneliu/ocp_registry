module Ocp::Registry

  class Error < StandardError
    def self.code(code = 500)
      define_method(:code) { code }
    end
  end

  class FatalError < Error; end

  class ConfigError < Error; end
  class ConnectionError < Error; end

  class CloudError < Error ; end

end