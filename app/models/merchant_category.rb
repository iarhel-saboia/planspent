# Remembers the category the user chose for a transaction description, so the same merchant
# gets it automatically next time. Manual choices always win over automatic ones.
class MerchantCategory < ApplicationRecord
  belongs_to :category

  enum :source, { automatic: 0, manual: 1 }

  validates :pattern, presence: true, uniqueness: true

  # "UBER *TRIP 12/10 SAO PAULO" -> "uber trip sao paulo"
  def self.pattern_for(description)
    I18n.transliterate(description.to_s).downcase.gsub(/[^a-z ]/, " ").squish
  end

  def self.lookup(description)
    pattern = pattern_for(description)
    find_by(pattern: pattern)&.category if pattern.present?
  end

  def self.remember(description, category, source:)
    pattern = pattern_for(description)
    return if pattern.blank?

    record = find_or_initialize_by(pattern: pattern)
    return if record.manual? && source == :automatic && record.persisted?

    record.update!(category: category, source: source)
  end
end
