# frozen_string_literal: true

module StringEnum

  # Usage
  # include StringEnum[
  #   state: { enum: %w[choice in_delivery], i18n_scope: 'line_item.state' },
  #   color: { enum: %w[red green yellow], prefix_field: 'color' },
  #   type:  { enum: %w[CartType BookmarkType] },
  # ]
  def self.[](args)
    Module.new do
      args.each do |attr, params|
        enum_values  = params.fetch(:enum)
        i18n_scope   = params.fetch(:i18n_scope, nil)
        prefix_field = params.fetch(:prefix_field, nil)

        enum_values.each do |enum_value|
          enum_value_name =
            if prefix_field
              "#{attr}_#{enum_value}"
            else
              enum_value
            end

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def active?
            #   state == 'active'
            # end

            def #{enum_value_name}?
              #{attr} == '#{enum_value_name}'
            end
          RUBY

          next unless i18n_scope

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def state_i18n
            #   ::I18n.t(state, scope: "enums.product.state", default: state)
            # end

            def #{attr}_i18n
              ::I18n.t(#{attr}, scope: "enums.#{i18n_scope}", default: #{attr})
            end
          RUBY
        end
      end
    end
  end

end
