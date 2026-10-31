module BrazilianDecimal
  extend ActiveSupport::Concern

  class_methods do
    # Makes the attributes accept Brazilian format ("1.234,56") as well as "1234.56"
    def brazilian_decimal(*attributes)
      attributes.each do |attribute|
        define_method(:"#{attribute}=") do |value|
          value = value.delete(".").tr(",", ".") if value.is_a?(String) && value.include?(",")
          super(value)
        end
      end
    end
  end
end
