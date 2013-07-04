# Copyright (c) 2009-2013 VMware, Inc.

module Ocp::Registry::Models
  class RegistryApplication < Sequel::Model

    def validate
      validates_presence [:app_id, :request]
      validates_unique :app_id
    end

  end
end