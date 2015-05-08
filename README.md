## rails_string_enum
support in rails db enums or string (using as flexible enum)

This gem inspired rails native enum and  https://github.com/zmbacker/enum_help
## Installation

Add this line to your application's Gemfile:

    gem 'rails_string_enum'


Tested on Rails 4.2, ruby 2.2

#### Native postgresql enum (migrations)
```ruby

create_enum :color, %w(red green blue) # default schema is 'public'
create_enum :color, %w(red green blue), schema: 'cmyk'

add_enum_value :color, 'black'
add_enum_value :color, 'black', after: 'red'
add_enum_value :color, 'black', before: 'blue'
add_enum_value :color, 'black', schema: 'public'

drop_enum :color
drop_enum :color, schema: 'cmyk'

rename_enum_value :color, 'gray', 'black'
reorder_enum_values :order_state_enum, %w(black white) # other color will be latest

delete_enum_value :color, 'black'
# you should delete record with deleting value
# if exists index with condition method raise exeption
# "ERROR: operator does not exist: order_type_enum <> order_type_enum_new"
# you should first remove and then create an index
  Product.where(color: 'black').delete_all # or Product.where(color: 'black').update_all(state: nil)
  remove_index :product, :color, where: "color NOT IN ('pink')"
  delete_enum_value :color, 'black'
  add_index :product, :color, where: "color NOT IN ('pink')"
```

###### Convert exist columns (int, string) to postgresql enum
```ruby
string_to_enums :product, :color, enum_name: 'product_color_enum', definitions: %w(red green blue)
string_to_enums :product, :color, enum_name: 'product_color_enum', definitions: Product.uniq.pluck(:color)

int_to_enums :product, :color, enum_name: 'product_color_enum', definitions: { red: 0, green: 1, blue: 2 }
```


#### Usage
```ruby
class CreateTables < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :color
    end
    
    create_enum :enum_color, %w(red green blue)
    
    create_table :pages do |t|
      t.column :color, :enum_color, default: 'red'
    end
  end
end

class Product < ActiveRecord::Base
  string_enum :color, %w(red green yellow black white), scopes: true # default false
  
  def self.colored
    where.not(color: [COLOR::BLACK, COLOR::WHITE])
  end
end

class Page < ActiveRecord::Base
  string_enum :background, %w(red green), i18n_scope: 'product.color'
end

Product::COLORS # => ["red", "green", "yellow"]
Product::COLOR::RED # => "red"
Product::COLOR::GREEN # => "green"

@product = Product.new
@product.color_i18n  # => nil
@product.red!
@product.color_i18n # => 'Красный'

Product.color_i18n_for('red') # => 'Красный'
Product.colors_i18n # => {green: 'Зеленый', red: 'Красный', yellow: 'Желтый'}
Product.red # if scopes: true
```


I18n local file example (compatible with https://github.com/zmbacker/enum_help):

```yaml
# config/locals/ru.yml
ru:
  enums:
    product:
      color:
        red: Красный
        green: Зеленый
        yellow: Желтый
```

Support `simple_form`:
```erb
<%= f.input :color %>
```

#### Benchmark i18n methods (rails_string_enum faster 2x then enum_help)

```ruby
Benchmark.ips do |x|
  x.report('rails_string_enum')   { u.social_app_i18n }
  x.report('enum_help')           { u.social_app_i18n_eh }
  x.report('rails_string_enum_c') { Order.states_i18n }
  x.report('enum_help_c')         { Order.states_i18n_eh }
end

Calculating -------------------------------------
   rails_string_enum     3.149k i/100ms
           enum_help     1.489k i/100ms
 rails_string_enum_c     3.002k i/100ms
         enum_help_c     1.384k i/100ms
-------------------------------------------------
   rails_string_enum     42.727k (± 4.4%) i/s -    214.132k
           enum_help     16.686k (±11.9%) i/s -     81.895k
 rails_string_enum_c     38.159k (± 5.3%) i/s -    192.128k
         enum_help_c     15.939k (± 4.5%) i/s -     80.272k
```

