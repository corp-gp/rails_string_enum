module PgEnumMigrations

  # create_enum :color, %w(red green blue) # default schema is 'public'
  # create_enum :color, %w(red green blue), schema: 'cmyk'
  def create_enum(enum_name, values, schema: 'public')
    execute "CREATE TYPE #{enum_name(enum_name, schema)} AS ENUM (#{escape_enum_values(values)})"
  end


  # add_enum_value :color, 'black'
  # add_enum_value :color, 'purple', after: 'red'
  # add_enum_value :color, 'pink', before: 'purple'
  # add_enum_value :color, 'white', schema: 'public'
  # **WARN** cannot run inside a transaction block
  def add_enum_value(enum_name, value, before: nil, after: nil, schema: 'public')
    opts = if    before then "BEFORE #{escape_enum_value(before)}"
           elsif after  then "AFTER #{escape_enum_value(after)}"
           else  ''
           end
    execute "ALTER TYPE #{enum_name(enum_name, schema)} ADD VALUE IF NOT EXISTS #{escape_enum_value(value)} #{opts}"
  end

  # drop_enum :color
  # drop_enum :color, schema: 'cmyk'
  def drop_enum(enum_name, schema: nil)
    execute "DROP TYPE #{enum_name(enum_name, schema)}"
  end


  # you should delete record with deleting value
  # Product.only_purple.delete_all or Product.purple.update_all(color: nil)
  #
  # if exists index with condition - add_index :products, :color, where: "color NOT IN ('white', 'black')"
  # this method show exeption ERROR: operator does not exist: color <> color_new
  # you must first remove and then create an index
  #
  # delete_enum_value :color, 'black'
  def delete_enum_value(enum_name, value_name, scheme: 'public')
    old_values = select_values("SELECT enumlabel FROM pg_catalog.pg_enum WHERE enumtypid = '#{scheme}.#{enum_name}'::regtype::oid")
    new_values = old_values - Array(value_name)

    execute <<-SQL
      ALTER TYPE #{enum_name} rename to #{enum_name}_old;
      CREATE TYPE #{enum_name} AS enum (#{escape_enum_values(new_values)});
    SQL

    cols_using_enum = select_rows("SELECT table_name, column_name, column_default FROM information_schema.columns WHERE udt_name = '#{enum_name}_old'")
    cols_using_enum.each do |table_name, column_name, column_default|
      unless column_default.nil?
        raise "column #{table_name}.#{column_name} has default value #{column_default}, you must manually drop default"
      end
      execute <<-SQL
        ALTER TABLE #{table_name}
        ALTER COLUMN #{column_name} TYPE #{enum_name} USING #{column_name}::text::#{enum_name};
      SQL
    end

    execute <<-SQL
      DROP TYPE #{enum_name}_old
    SQL
  end



  # rename_enum_value :color, 'white', 'pale'
  def rename_enum_value(enum_name, old_value_name, new_value_name, scheme: 'public')
    execute <<-SQL
      UPDATE pg_catalog.pg_enum
      SET enumlabel = '#{new_value_name}'
      WHERE enumtypid = '#{scheme}.#{enum_name}'::regtype::oid AND enumlabel = '#{old_value_name}'
    SQL
  end



  # reorder_enum_values :color, %w(green pale red blue)
  def reorder_enum_values(enum_name, ordered_values, scheme: 'public')
    all_values = select_values("SELECT enumlabel FROM pg_catalog.pg_enum WHERE enumtypid = '#{scheme}.#{enum_name}'::regtype::oid")
    max_order =  select_value("SELECT max(enumsortorder) FROM pg_catalog.pg_enum WHERE enumtypid = '#{scheme}.#{enum_name}'::regtype::oid").to_i + 1

    ordered_sql = (ordered_values | all_values).map.with_index{|v, i| "WHEN '#{v}' THEN #{i + max_order}"}.join(' ')

    execute <<-SQL
      UPDATE pg_catalog.pg_enum
      SET enumsortorder = CASE enumlabel #{ordered_sql} END
      WHERE enumtypid = '#{scheme}.#{enum_name}'::regtype::oid
    SQL
  end



  # string_to_enums :order, :state, enum_name: 'order_state_enum', definitions: %w(accept confirmed)
  def string_to_enums(table, col_name, enum_name:, definitions: nil, default: nil, use_exist_enum: false)
    convert_to_enum table, col_name, enum_name, definitions, col_name, default, use_exist_enum
  end



  # int_to_enums :users, :partner_type, enum_name: 'user_partner_type_enum', definitions: { retail: 0, affiliate: 1, wholesale: 2 }
  def int_to_enums(table, col_name, enum_name:, definitions: nil, default: nil, use_exist_enum: false)
    convert_sql = definitions.map {|str, int| "WHEN #{int} THEN '#{str}'" }.join(' ')
    convert_sql = "CASE #{col_name} #{convert_sql} END"

    convert_to_enum table, col_name, enum_name, definitions.keys, convert_sql, default, use_exist_enum
  end



  private

  def enum_name(name, schema)
    [schema || 'public', name].map { |s|
      %Q{"#{s}"}
    }.join('.')
  end

  def escape_enum_value(value)
    escaped_value = value.to_s.sub("'", "''")
    "'#{escaped_value}'"
  end

  def escape_enum_values(values)
    values.map { |value| escape_enum_value(value) }.join(',')
  end

  def convert_to_enum(table, col_name, enum_name, keys, convert_sql, default, use_exist_enum)
    schema = select_value("SELECT table_schema FROM information_schema.columns WHERE table_name = '#{table}'")

    execute "CREATE TYPE #{enum_name(enum_name, schema)} AS ENUM (#{escape_enum_values(keys)})" unless use_exist_enum

    default_sql = ", ALTER COLUMN #{col_name} SET DEFAULT '#{default}'" if default

    execute <<-SQL
      ALTER TABLE #{table}
      ALTER COLUMN #{col_name} DROP DEFAULT,
      ALTER COLUMN #{col_name} TYPE #{enum_name} USING #{convert_sql}::#{enum_name}
    #{default_sql};
    SQL
  end

end
