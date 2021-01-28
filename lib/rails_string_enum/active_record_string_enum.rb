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
    const_set attr.to_s.pluralize.upcase, enums.map(&:to_s).freeze

    klass = self

    i18n_scope ||= "#{klass.base_class.to_s.underscore}.#{attr}"

    klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
      # def state_i18n
      #   ::I18n.t(state, scope: "enums.product.state", default: state)
      # end

      def #{attr}_i18n
        ::I18n.t(#{attr}, scope: "enums.#{i18n_scope}", default: #{attr})
      end
    RUBY

    klass.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
      # def state_i18n_for(enum)
      #   ::I18n.t(enum, scope: "enums.product.state", default: enum)
      # end

      def #{attr}_i18n_for(enum)
        ::I18n.t(enum, scope: "enums.#{i18n_scope}", default: enum)
      end
    RUBY

    define_collection_i18n_method(self, attr, i18n_scope)

    enums.each do |value|
      value_method_name =
        if prefix_field
          "#{attr}_#{value}"
        else
          value
        end

      # Product::ACTIVE #=> "active"
      const_set value_method_name.upcase, value.to_s

      klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # def active?
        #   state == 'active'
        # end

        def #{value_method_name}?
          #{attr} == '#{value_method_name}'
        end
      RUBY

      if scopes
        # scope :only_active,  -> { where(color: 'active') }
        # scope :only_actives, -> { where(color: 'active') } # if scopes: { pluralize: true }
        scope_name = scopes.try(:fetch, :pluralize, nil) ? "only_#{value.to_s.pluralize}" : "only_#{value}"
        klass.send(:detect_enum_conflict!, attr, scope_name, true)
        klass.scope scope_name, -> { where(attr => value) }
      end
    end
  end

  # Product.statuses_i18n => { active: 'Активный', archived: 'В архивне' }
  private def define_collection_i18n_method(klass, attr_name, i18n_scope)
    collection_method_name = "#{attr_name.to_s.pluralize}_i18n"
    collection_const_name = "#{attr_name.to_s.pluralize.upcase}"

    klass.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{collection_method_name}
        h = HashWithIndifferentAccess.new
        self::#{collection_const_name}.each do |enum|
          h[enum] = ::I18n.t(enum, scope: "enums.#{i18n_scope}", default: enum)
        end
        h
      end
    RUBY
  end

  # for combinations constants to array, using `__` for split it
  # Product::RED__GREEN__YELLOW #=> ["red", "green", "yellow"]
  # Product::RED__GREEN__BLABLA #=> NameError: uninitialized constant Product::BLABLA
  private def const_missing(name)
    name_s = name.to_s
    return super unless name_s.include?('__')

    const_set name_s, name_s.split('__').map { |i| const_get(i) }.freeze
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
