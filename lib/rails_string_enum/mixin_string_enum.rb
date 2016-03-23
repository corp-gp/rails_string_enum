module MixinStringEnum

  # this is a simplified version ActiveRecordStringEnum, for any Class or Module, support only constants

  def string_enum(name, enums)

    const_name_all_values = name.to_s.pluralize.upcase
    const_set const_name_all_values, enums.map(&:to_s)

    klass = self
    enums.each do |value|
      const_set value.to_s.upcase, value.to_s
    end

  end


  private

  def const_missing(name)
    name_s = name.to_s
    return super unless name_s.include?('__')

    const_set name_s, name_s.split('__').map { |i| const_get(i) }
  end

end
