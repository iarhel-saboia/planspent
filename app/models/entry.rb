class Entry < ApplicationRecord
  include BrazilianDecimal

  enum :kind, { debit: 0, credit: 1 }, validate: true
  # "pending" only exists before the first save: new entries are categorized on create
  enum :categorization, { pending: 0, automatic: 1, manual: 2, uncategorized: 3 }, prefix: true

  belongs_to :category, optional: true
  belongs_to :goal, optional: true

  before_create :categorize_automatically, if: :categorization_pending?

  after_update_commit -> { broadcast_replace_to "entries" }, if: -> { saved_change_to_category_id? || saved_change_to_categorization? }

  validates :description, presence: true, length: { maximum: 120 }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :occurred_on, presence: true
  validate :withdrawal_within_goal, if: -> { goal && credit? && (new_record? || will_save_change_to_goal_id?) }
  validate :goal_takes_contributions, if: -> { goal && will_save_change_to_goal_id? }

  brazilian_decimal :amount

  scope :in_month, ->(date) { where(occurred_on: date.all_month) }
  scope :chronological, -> { order(occurred_on: :desc, created_at: :desc) }

  # Sets a category chosen by the user and teaches it to the merchant memory, re-categorizing
  # other automatically categorized entries with the same description
  def categorize_manually!(category)
    transaction do
      update!(category: category, categorization: :manual)
      MerchantCategory.remember(description, category, source: :manual)
      pattern = MerchantCategory.pattern_for(description)
      Entry.categorization_automatic.where.not(id: id).where.not(category: category).find_each do |entry|
        entry.update!(category: category) if MerchantCategory.pattern_for(entry.description) == pattern
      end
    end
  end

  MonthSummary = Data.define(:month, :credits, :debits, :income, :expenses, :invested_by_goal) do
    # All of the month's entries, as in the home page cards
    def balance = credits - debits

    # Money put aside in goals during the month, minus what was taken back
    def invested = invested_by_goal.values.sum(0.to_d)
  end

  # The month's totals: all credits and debits, income and expenses outside goals, and what was
  # invested in each goal
  def self.month_summary(month)
    month = month.beginning_of_month
    totals = in_month(month).group(:goal_id, :kind).sum(:amount).transform_values(&:to_d)
    invested = totals.keys.filter_map(&:first).uniq.to_h do |goal_id|
      [ goal_id, totals.fetch([ goal_id, "debit" ], 0) - totals.fetch([ goal_id, "credit" ], 0) ]
    end
    sum_kind = ->(kind) { totals.sum { |(_, k), amount| k == kind ? amount : 0 }.to_d }
    MonthSummary.new(month: month, credits: sum_kind.("credit"), debits: sum_kind.("debit"),
      income: totals.fetch([ nil, "credit" ], 0.to_d), expenses: totals.fetch([ nil, "debit" ], 0.to_d),
      invested_by_goal: invested)
  end

  # Balance (credits - debits) per month for entries before the given date, newest first
  def self.monthly_balances(before:)
    where(occurred_on: ...before)
      .pluck(:occurred_on, :kind, :amount)
      .group_by { |occurred_on, _, _| occurred_on.beginning_of_month }
      .map { |month, rows| { month: month, balance: rows.sum { |_, kind, amount| kind == "credit" ? amount : -amount } } }
      .sort_by { |report| report[:month] }
      .reverse
  end

  private

  def goal_takes_contributions
    errors.add(:goal, "mensal não recebe lançamentos") if goal.monthly?
  end

  def withdrawal_within_goal
    errors.add(:amount, "é maior que o valor guardado na meta") if amount && amount > goal.saved_amount
  end

  def categorize_automatically
    self.category ||= EntryCategorizer.category_for(description, kind: kind)
    self.categorization = category ? :automatic : :uncategorized
  end
end
