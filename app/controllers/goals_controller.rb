class GoalsController < ApplicationController
  before_action :set_goal, only: %i[show update destroy]

  def index
    goals = Goal.by_creation.to_a
    monthly, savings = goals.partition(&:monthly?)
    active, @completed_goals = savings.partition { |goal| !goal.completed? }
    @active_goals = monthly + active
    @total_saved = savings.sum(&:saved_amount)
  end

  def show
    @entries = @goal.entries.chronological.includes(:category, :goal)
  end

  def create
    @goal = Goal.new(goal_params)
    if @goal.save
      redirect_to goals_path, notice: "Meta criada!"
    else
      render_form_errors
    end
  end

  def update
    if @goal.update(goal_params)
      redirect_back_or_to goals_path, notice: "Meta atualizada."
    else
      render_form_errors
    end
  end

  def destroy
    @goal.destroy
    redirect_to goals_path, notice: "Meta removida. Os lançamentos dela continuam no extrato."
  end

  private

  def set_goal
    @goal = Goal.find(params[:id])
  end

  def goal_params
    params.expect(goal: %i[kind name target_amount target_percent monthly_basis target_date color])
  end

  def render_form_errors
    render turbo_stream: turbo_stream.replace(helpers.goal_form_id(@goal), partial: "goals/form", locals: { goal: @goal }),
      status: :unprocessable_content
  end
end
