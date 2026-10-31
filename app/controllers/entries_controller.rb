class EntriesController < ApplicationController
  def index
    @month = selected_month
    @entries = Entry.in_month(@month).chronological.includes(:category, :goal)
    @credits = @entries.credit.sum(:amount)
    @debits = @entries.debit.sum(:amount)
    @balance = @credits - @debits
    @available_months = available_months
    @goals = Goal.by_creation.to_a
    @monthly_goals = @goals.select(&:monthly?)
    @savings_goals = @goals.select(&:savings?).reject(&:completed?).first(3)
  end

  def create
    @entry = Entry.new(entry_params)

    if @entry.save
      redirect_to root_path(month: @entry.occurred_on.strftime("%Y-%m")),
        notice: @entry.credit? ? "Crédito adicionado!" : "Gasto adicionado!"
    else
      render turbo_stream: turbo_stream.replace("#{@entry.kind}_form", partial: "entries/form", locals: { entry: @entry }),
        status: :unprocessable_content
    end
  end

  # From the entry row: manual category change, or linking the entry to a savings goal
  def update
    entry = Entry.find(params[:id])
    return link_goal(entry) if params[:entry]&.key?(:goal_id)

    entry.categorize_manually!(Category.find(params.expect(entry: [ :category_id ])[:category_id]))
    render turbo_stream: turbo_stream.replace(entry)
  end

  def destroy
    entry = Entry.find(params[:id])
    entry.destroy
    redirect_to root_path(month: entry.occurred_on.strftime("%Y-%m")), notice: "Lançamento removido."
  end

  private

  def link_goal(entry)
    goal = Goal.savings.find_by(id: params[:entry][:goal_id])
    if entry.update(goal: goal)
      notice = goal ? "Lançamento vinculado à meta #{goal.name}." : "Lançamento desvinculado da meta."
      redirect_back_or_to root_path(month: entry.occurred_on.strftime("%Y-%m")), notice: notice
    else
      redirect_back_or_to root_path, alert: entry.errors.full_messages.to_sentence
    end
  end

  def entry_params
    params.expect(entry: %i[description amount kind occurred_on])
  end

  # Accepts ?month=YYYY-MM (header select) or ?year=YYYY&month_number=M (past reports search)
  def selected_month
    if params[:year].present? && params[:month_number].present?
      Date.new(params[:year].to_i, params[:month_number].to_i, 1)
    else
      Date.strptime(params[:month].to_s, "%Y-%m").beginning_of_month
    end
  rescue Date::Error
    Date.current.beginning_of_month
  end

  # 6 months before the current one, the current month and 5 months after, in ascending order
  def available_months
    current = Date.current.beginning_of_month
    months = (-6..5).map { |offset| current >> offset }
    (months + [ @month ]).uniq.sort
  end
end
