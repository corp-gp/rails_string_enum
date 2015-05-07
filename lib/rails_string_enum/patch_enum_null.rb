require 'active_record/connection_adapters/postgresql/oid/enum'

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Enum < Type::Value # :nodoc:
          def type_cast(value)
            unless value.nil?
              value.to_s
            end
          end
        end
      end
    end
  end
end