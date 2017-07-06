require 'simple_form'

module BuilderExtensionWithEnum
  def default_input_type(*args, &block)
    attr_name = (args.first || @attribute_name).to_s
    options = args.last

    const_for_attr = object.respond_to? "#{attr_name}_i18n"

    return :enum_radio_buttons if options.is_a?(Hash) && options[:as] == :radio_buttons && const_for_attr
    return :enum if (options.is_a?(Hash) ? options[:as] : @options[:as]).nil? && const_for_attr

    super(*args, &block)
  end
end

module EnumHelp
  module SimpleForm
    module InputExtension

      def initialize(*args)
        super
        enum = input_options[:collection] || @builder.options[:collection]
        raise "Attribute '#{attribute_name}' has no enum class" unless enum ||= object.class.const_get(attribute_name.to_s.pluralize.upcase)

        collect = begin
          collection = object.class.send("#{attribute_name.to_s.pluralize}_i18n")
          collection.slice!(*enum) if enum
          collection.invert.to_a
        end

        # collect.unshift [args.last[:prompt],''] if args.last.is_a?(Hash) && args.last[:prompt]

        if respond_to?(:input_options)
          input_options[:collection] = collect
        else
          @builder.options[:collection] = collect
        end
      end

    end

  end
end


class EnumHelp::SimpleForm::EnumInput < ::SimpleForm::Inputs::CollectionSelectInput
  include EnumHelp::SimpleForm::InputExtension
  def input_html_classes
    super.push('form-control')
  end
end


class EnumHelp::SimpleForm::EnumRadioButtons < ::SimpleForm::Inputs::CollectionRadioButtonsInput
  include EnumHelp::SimpleForm::InputExtension
end


SimpleForm::FormBuilder.class_eval do
  map_type :enum,               :to => EnumHelp::SimpleForm::EnumInput
  map_type :enum_radio_buttons, :to => EnumHelp::SimpleForm::EnumRadioButtons
  alias_method :collection_enum_radio_buttons, :collection_radio_buttons
  alias_method :collection_enum, :collection_select
  prepend BuilderExtensionWithEnum
end
