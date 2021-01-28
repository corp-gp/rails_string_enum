# frozen_string_literal: true

require 'rails_string_enum/version'
require 'rails_string_enum/string_enum'

if defined? ActiveRecord::Base
  require 'rails_string_enum/active_record_string_enum'
  ActiveRecord::Base.send :extend, ActiveRecordStringEnum
end

require 'active_record/connection_adapters/postgresql_adapter'
if defined? ActiveRecord::ConnectionAdapters::PostgreSQL
  require 'rails_string_enum/pg_enum_migration'
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send :include, PgEnumMigrations
end

begin
  require 'simple_form'
  require 'rails_string_enum/simple_form'
rescue LoadError
end
