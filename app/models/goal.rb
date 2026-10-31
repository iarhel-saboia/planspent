# Two kinds of goals:
# - savings: something the user is saving money for. Money is put aside (or taken back) through
#   entries linked to the goal, so contributions also show up in the month's balance.
# - monthly: invest a fixed amount or a share of the income every month. What counts is the money put
#   aside in savings goals during the month ("Guardar" or linked entries), minus withdrawals.
class Goal < ApplicationRecord
  include BrazilianDecimal

  # Full class names so Tailwind picks them up
  COLORS = {
    "indigo" => { dot: "bg-indigo-500", bar: "bg-indigo-500", soft: "bg-indigo-50 dark:bg-indigo-500/15 text-indigo-600 dark:text-indigo-400" },
    "emerald" => { dot: "bg-emerald-500", bar: "bg-emerald-500", soft: "bg-emerald-50 dark:bg-emerald-500/15 text-emerald-600 dark:text-emerald-400" },
    "sky" => { dot: "bg-sky-500", bar: "bg-sky-500", soft: "bg-sky-50 dark:bg-sky-500/15 text-sky-600 dark:text-sky-400" },
    "amber" => { dot: "bg-amber-500", bar: "bg-amber-500", soft: "bg-amber-50 dark:bg-amber-500/15 text-amber-600 dark:text-amber-400" },
    "rose" => { dot: "bg-rose-500", bar: "bg-rose-500", soft: "bg-rose-50 dark:bg-rose-500/15 text-rose-600 dark:text-rose-400" },
    "violet" => { dot: "bg-violet-500", bar: "bg-violet-500", soft: "bg-violet-50 dark:bg-violet-500/15 text-violet-600 dark:text-violet-400" },
    "teal" => { dot: "bg-teal-500", bar: "bg-teal-500", soft: "bg-teal-50 dark:bg-teal-500/15 text-teal-600 dark:text-teal-400" },
    "pink" => { dot: "bg-pink-500", bar: "bg-pink-500", soft: "bg-pink-50 dark:bg-pink-500/15 text-pink-600 dark:text-pink-400" }
  }.freeze

  CONTRIBUTION_CATEGORY = "Investimentos"

  MonthResult = Data.define(:month, :invested, :target, :income) do
    # A share of no income is zero: such a month only counts as hit if something was invested
    def hit? = target.positive? ? invested >= target : invested.positive?
    def percent = target.positive? ? (invested / target * 100).floor.clamp(0, 100) : (hit? ? 100 : 0)
    def surplus = invested - target

    # Nothing came in and nothing was invested: shown as neutral instead of hit or missed
    def empty? = income.zero? && invested.zero?
  end

  enum :kind, { savings: 0, monthly: 1 }, validate: true

  has_many :entries, dependent: :nullify

  attr_writer :monthly_basis

  before_validation :apply_monthly_basis, if: :monthly?

  validates :name, presence: true, length: { maximum: 60 }
  validates :target_amount, presence: true, numericality: { greater_than: 0 }, unless: -> { monthly? && target_percent }
  validates :target_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :color, inclusion: { in: COLORS.keys }
  validate :target_date_in_the_future, if: -> { savings? && target_date && will_save_change_to_target_date? }

  brazilian_decimal :target_amount, :target_percent

  scope :by_creation, -> { order(:created_at) }

  # Monthly goals: "amount" (fixed amount per month) or "percent" (share of the month's income)
  def monthly_basis
    @monthly_basis.presence || (target_percent ? "percent" : "amount")
  end

  def to_partial_path
    monthly? ? "goals/monthly_goal" : "goals/goal"
  end

  def colors
    COLORS.fetch(color, COLORS["indigo"])
  end

  # Money put aside minus money taken back
  def saved_amount
    @saved_amount ||= entries.sum(Arel.sql("CASE kind WHEN #{Entry.kinds[:debit]} THEN amount ELSE -amount END")).to_d
  end

  def remaining_amount
    [ target_amount - saved_amount, 0 ].max
  end

  # 0..100
  def progress_percent
    (saved_amount / target_amount * 100).floor.clamp(0, 100)
  end

  def completed?
    savings? && saved_amount >= target_amount
  end

  # Months until the deadline, counting the current one ("dez/2027" seen in out/2026 -> 15)
  def months_left(today = Date.current)
    return unless target_date

    [ (target_date.year * 12 + target_date.month) - (today.year * 12 + today.month) + 1, 0 ].max
  end

  # How much to put aside per month to reach the target on time
  # How much to put aside per month to reach the target on time: this month's share until it's met,
  # then the rest spread over the following months
  def monthly_needed(today = Date.current)
    return if completed? || !target_date || target_date < today

    share = month_target(today)
    invested_this_month = saved_amount - saved_before(today.beginning_of_month)
    if share && invested_this_month >= share && months_left(today) > 1
      (remaining_amount / (months_left(today) - 1)).round(2)
    else
      share
    end
  end

  # This month's share of a savings goal, fixed at the start of the month: contributions made during
  # the month count toward it instead of lowering it
  def month_target(month = Date.current)
    month = month.beginning_of_month
    return if !savings? || !target_date || target_date < month

    remaining = target_amount - saved_before(month)
    (remaining / months_left(month)).round(2) if remaining.positive?
  end

  # :completed, :overdue (deadline passed), :behind, :on_track or :no_deadline
  def status(today = Date.current)
    return :completed if completed?
    return :no_deadline unless target_date
    return :overdue if target_date < today

    saved_amount >= expected_amount(today) ? :on_track : :behind
  end

  # Contributions expected by now if saving evenly from the creation date to the deadline
  def expected_amount(today = Date.current)
    start = created_at&.to_date || today
    total_days = (target_date - start).to_i
    return target_amount if total_days <= 0

    (target_amount * ((today - start).to_i.clamp(0, total_days).to_d / total_days)).round(2)
  end

  # Puts money aside (debit) or takes it back (credit) through an entry in the month's statement
  def contribute(amount:, occurred_on:, withdrawal: false)
    @saved_amount = nil
    entries.create(
      amount: amount,
      occurred_on: occurred_on,
      kind: withdrawal ? :credit : :debit,
      description: withdrawal ? "Resgate da meta: #{name}" : "Meta: #{name}",
      category: Category.find_by(name: CONTRIBUTION_CATEGORY),
      categorization: :manual
    )
  end

  # Monthly goals: how much was invested in the month and how much should have been
  def month_result(month)
    month = month.beginning_of_month
    @month_results ||= {}
    @month_results[month] ||= begin
      summary = Entry.month_summary(month)
      target = target_percent ? (summary.income * target_percent / 100).round(2) : target_amount
      MonthResult.new(month: month, invested: summary.invested, target: target, income: summary.income)
    end
  end

  # The last months up to the given one, oldest first
  def month_history(month = Date.current, size: 6)
    (0...size).map { |offset| month_result(month.beginning_of_month << offset) }.reverse
  end

  # Months in a row the goal was hit, counting back from the given month (which counts only if already hit)
  def streak(month = Date.current)
    results = month_history(month, size: 12).reverse
    results = results.drop(1) unless results.first.hit?
    results.take_while(&:hit?).size
  end

  private

  def saved_before(date)
    entries.where(occurred_on: ...date).sum(Arel.sql("CASE kind WHEN #{Entry.kinds[:debit]} THEN amount ELSE -amount END")).to_d
  end

  def apply_monthly_basis
    self.target_date = nil
    if monthly_basis == "percent"
      self.target_amount = nil
    else
      self.target_percent = nil
    end
  end

  def target_date_in_the_future
    errors.add(:target_date, "deve ser uma data futura") if target_date < Date.current
  end
end
