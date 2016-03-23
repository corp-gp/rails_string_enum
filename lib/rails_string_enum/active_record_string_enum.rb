module ActiveRecordStringEnum

  # product.rb
  # string_enum :color, %w(red green yellow)
  # page.rb
  # string_enum :background, %w(red green), i18n_scope: 'product.color', scopes: { pluralize: true }

  def string_enum(name, enums, scopes: false, i18n_scope: nil)
    # create constant with all values
    # Product::COLORS # => ["red", "green", "yellow"]
    const_name_all_values = name.to_s.pluralize.upcase
    const_set const_name_all_values, enums.map(&:to_s)

    klass = self
    enums.each do |value|
      # Product::RED #=> "red"
      const_set value.to_s.upcase, value.to_s

      # def red?() color == 'red' end
      klass.send(:detect_enum_conflict!, name, "#{value}?")
      klass.class_eval <<-METHOD, __FILE__, __LINE__
        def #{value}?
          #{name} == #{value.to_s.upcase}
        end
      METHOD

      # def red!() update! color: :red end
      klass.send(:detect_enum_conflict!, name, "#{value}!")
      define_method("#{value}!") { update! name => value }

      if scopes
        # scope :only_red, -> { where color: 'red' }
        # scope :only_reds, -> { where color: 'red' } # if scopes: { pluralize: true }
        scope_name = scopes.try(:fetch, :pluralize, nil) ? "only_#{value.to_s.pluralize}" : "only_#{value}"
        klass.send(:detect_enum_conflict!, name, scope_name, true)
        klass.scope scope_name, -> { klass.where name => value }
      end
    end

    define_attr_i18n_method(self, name, i18n_scope)
    define_collection_i18n_method(self, name, i18n_scope)
    define_collection_i18n_method_for_value(self, name, i18n_scope)
  end


  private

  ENUM_CONFLICT_MESSAGE = \
      "You tried to define an enum named \"%{enum}\" on the model \"%{klass}\", but " \
      "this will generate a %{type} method \"%{method}\", which is already defined " \
      "by %{source}."

  def detect_enum_conflict!(enum_name, method_name, klass_method = false)
    if klass_method && dangerous_class_method?(method_name)
      raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
                             enum: enum_name,
                             klass: self.name,
                             type: 'class',
                             method: method_name,
                             source: 'Active Record'
                         }
    elsif !klass_method && dangerous_attribute_method?(method_name)
      raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
                             enum: enum_name,
                             klass: self.name,
                             type: 'instance',
                             method: method_name,
                             source: 'Active Record'
                         }
    elsif !klass_method && method_defined_within?(method_name, _enum_methods_module, Module)
      raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
                             enum: enum_name,
                             klass: self.name,
                             type: 'instance',
                             method: method_name,
                             source: 'another enum'
                         }
    end
  end


  # @product.color_i18n => 'Красный'
  def define_attr_i18n_method(klass, attr_name, i18n_scope)
    attr_i18n_method_name = "#{attr_name}_i18n"

    klass.class_eval <<-METHOD, __FILE__, __LINE__
      def #{attr_i18n_method_name}
        if enum_label = self.send(:#{attr_name})
          #{ruby_string_for_enum_label(klass, attr_name, i18n_scope)}
        else
          nil
        end
      end

      def #{attr_i18n_method_name}_for
          #{ruby_string_for_enum_label(klass, attr_name, i18n_scope)}
      end
    METHOD
  end

  # Product.color_i18n_for('red') => 'Красный'
  def define_collection_i18n_method_for_value(klass, attr_name, i18n_scope)
    attr_i18n_method_name = "#{attr_name}_i18n"

    klass.instance_eval <<-METHOD, __FILE__, __LINE__
      def #{attr_i18n_method_name}_for(enum_label)
        return nil unless enum_label
        #{ruby_string_for_enum_label(klass, attr_name, i18n_scope)}
      end
    METHOD
  end

  # Product.colors_i18n => {green: 'Зеленый', red: 'Красный', yellow: 'Желтый'}
  def define_collection_i18n_method(klass, attr_name, i18n_scope)
    collection_method_name = "#{attr_name.to_s.pluralize}_i18n"
    collection_const_name = "#{attr_name.to_s.pluralize.upcase}"

    klass.instance_eval <<-METHOD, __FILE__, __LINE__
      def #{collection_method_name}
        h = HashWithIndifferentAccess.new
        self::#{collection_const_name}.each do |enum_label|
          h[enum_label] = #{ruby_string_for_enum_label(klass, attr_name, i18n_scope)}
        end
        h
      end
    METHOD
  end

  def ruby_string_for_enum_label(klass, attr_name, i18n_scope)
    part_scope = i18n_scope || "#{klass.base_class.to_s.underscore}.#{attr_name}"
    %Q{::I18n.t(enum_label, scope: "enums.#{part_scope}", default: enum_label)}
  end


  # for combinations constants to array, using `__` for split it
  # Product::RED__GREEN__YELLOW #=> ["red", "green", "yellow"]
  # Product::RED__GREEN__BLABLA #=> NameError: uninitialized constant Product::BLABLA
  def const_missing(name)
    name_s = name.to_s
    return super unless name_s.include?('__')

    const_set name_s, name_s.split('__').map { |i| const_get(i) }
  end

end
