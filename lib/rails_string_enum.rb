require 'rails_string_enum/version'


require 'rails_string_enum/pg_enum_migration'
require 'active_record/connection_adapters/postgresql_adapter'
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send :include, PgEnumMigrations


require 'rails_string_enum/string_enum'
ActiveRecord::Base.send :extend, RailsStringEnum


require 'rails_string_enum/patch_enum_null' if Rails.version <= "4.2.1"


begin
  require 'simple_form'
  require 'rails_string_enum/simple_form'
rescue
end