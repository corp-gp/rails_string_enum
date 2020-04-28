# frozen_string_literal: true

module ActiveRecordStringEnum

  # product.rb
  # string_enum :status, %w[active archived]

  # page.rb
  # string_enum :background, %w(red green), i18n_scope: 'product.color', scopes: { pluralize: true }

  def string_enum(attr, enums, scopes: false, i18n_scope: nil, prefix_field: false)

    detect_enum_conflict!(attr, attr)
    detect_enum_conflict!(attr, "#{attr}=")
    detect_enum_conflict!(attr, attr.to_s.pluralize, true)

    # create constant with all values
    # Product::STATUSES # => ["active", "archived"]
    const_name_all_values = attr.to_s.pluralize.upcase
    const_set const_name_all_values, enums.map(&:to_s)

    define_attr_i18n_method(self, attr, i18n_scope)
    define_collection_i18n_method(self, attr, i18n_scope)
    define_collection_i18n_method_for_value(self, attr, i18n_scope)

    klass = self

    enums.each do |value|
      # Product::ACTIVE #=> "active"

      value_method_name =
        if prefix_field
          "#{attr}_#{value}"
        else
          value
        end

      const_set value_method_name.upcase, value.to_s

      # def active?() status == "active" end
      klass.send(:detect_enum_conflict!, attr, "#{value_method_name}?")
      klass.class_eval <<-METHOD, __FILE__, __LINE__
        def #{value_method_name}?
          #{attr} == #{value_method_name.to_s.upcase}
        end
      METHOD

      # def active!() update!(status: 'active') end
      klass.send(:detect_enum_conflict!, attr, "#{value_method_name}!")
      define_method("#{value_method_name}!") { update!(attr => value) }

      if scopes
        # scope :only_active,  -> { where(color: 'active') }
        # scope :only_actives, -> { where(color: 'active') } # if scopes: { pluralize: true }
        scope_name = scopes.try(:fetch, :pluralize, nil) ? "only_#{value.to_s.pluralize}" : "only_#{value}"
        klass.send(:detect_enum_conflict!, attr, scope_name, true)
        klass.scope scope_name, -> { where(attr => value) }
      end
    end
  end


  # @product.status_i18n => 'Активный'
  private def define_attr_i18n_method(klass, attr_name, i18n_scope)
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

  # Product.status_i18n_for('active') => 'Активный'
  private def define_collection_i18n_method_for_value(klass, attr_name, i18n_scope)
    attr_i18n_method_name = "#{attr_name}_i18n"

    klass.instance_eval <<-METHOD, __FILE__, __LINE__
      def #{attr_i18n_method_name}_for(enum_label)
        return nil unless enum_label
        #{ruby_string_for_enum_label(klass, attr_name, i18n_scope)}
      end
    METHOD
  end

  # Product.statuses_i18n => { active: 'Активный', archived: 'В архивне' }
  private def define_collection_i18n_method(klass, attr_name, i18n_scope)
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

  private def ruby_string_for_enum_label(klass, attr_name, i18n_scope)
    part_scope = i18n_scope || "#{klass.base_class.to_s.underscore}.#{attr_name}"
    %Q{::I18n.t(enum_label, scope: "enums.#{part_scope}", default: enum_label)}
  end


  # for combinations constants to array, using `__` for split it
  # Product::RED__GREEN__YELLOW #=> ["red", "green", "yellow"]
  # Product::RED__GREEN__BLABLA #=> NameError: uninitialized constant Product::BLABLA
  private def const_missing(name)
    name_s = name.to_s
    return super unless name_s.include?('__')

    const_set name_s, name_s.split('__').map { |i| const_get(i) }
  end


  ENUM_CONFLICT_MESSAGE = \
        "You tried to define an enum named \"%{enum}\" on the model \"%{klass}\", but " \
        "this will generate a %{type} method \"%{method}\", which is already defined " \
        "by %{source}."
  private_constant :ENUM_CONFLICT_MESSAGE

  private def detect_enum_conflict!(enum_name, method_name, klass_method = false)
    if klass_method && dangerous_class_method?(method_name)
      raise_conflict_error(enum_name, method_name, type: "class")
    elsif !klass_method && dangerous_attribute_method?(method_name)
      raise_conflict_error(enum_name, method_name)
    elsif !klass_method && method_defined_within?(method_name, _enum_methods_module, Module)
      raise_conflict_error(enum_name, method_name, source: "another enum")
    end
  end

  private def raise_conflict_error(enum_name, method_name, type: "instance", source: "Active Record")
    raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
        enum: enum_name,
        klass: name,
        type: type,
        method: method_name,
        source: source
    }
  end

  private def detect_negative_condition!(method_name)
    if method_name.start_with?("not_") && logger
      logger.warn "An enum element in #{self.name} uses the prefix 'not_'." \
            " This will cause a conflict with auto generated negative scopes."
    end
  end

end
