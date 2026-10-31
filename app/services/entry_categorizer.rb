# Assigns a category to entries from their description, with no external service: corrections the
# user made before (merchant memory) come first, then the keyword rules in config/category_rules.yml.
class EntryCategorizer
  RULES_FILE = Rails.root.join("config/category_rules.yml")
  CREDIT_ONLY = [ "Salário" ].freeze

  # Returns the category for a description, or nil when nothing matches
  def self.category_for(description, kind:)
    MerchantCategory.lookup(description) || rule_category(description, kind)
  end

  # Categorizes and saves the given entries; returns how many got a category
  def self.call(entries)
    entries.count do |entry|
      category = category_for(entry.description, kind: entry.kind)
      entry.update!(category: category, categorization: category ? :automatic : :uncategorized)
      category.present?
    end
  end

  def self.rule_category(description, kind)
    words = " #{normalize(description)} "
    name, = rules.find do |category_name, keywords|
      next false if CREDIT_ONLY.include?(category_name) && kind.to_s != "credit"

      keywords.any? { |keyword| words.include?(" #{keyword} ") }
    end
    Category.find_by(name: name) if name
  end

  # Keeps digits (unlike the merchant memory), so "99 pop" and "123milhas" can match
  def self.normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]/, " ").squish
  end

  def self.rules
    @rules ||= YAML.load_file(RULES_FILE).transform_values { |keywords| Array(keywords).map { |k| normalize(k) } }
  end
end
