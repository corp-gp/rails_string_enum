require 'rails_string_enum/version'
require 'rails_string_enum/mixin_string_enum'


if defined? ActiveRecord::Base
  require 'rails_string_enum/active_record_string_enum'
  ActiveRecord::Base.send :extend, ActiveRecordStringEnum
end


require 'active_record/connection_adapters/postgresql_adapter'
if defined? ActiveRecord::ConnectionAdapters::PostgreSQL
  require 'rails_string_enum/pg_enum_migration'
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send :include, PgEnumMigrations

  require 'rails_string_enum/patch_enum_null' if Rails.version <= "4.2.1"
end


begin
  require 'simple_form'

  begin
    require('enum_help')
  rescue LoadError
    require 'rails_string_enum/simple_form'
  end

rescue LoadError
end
