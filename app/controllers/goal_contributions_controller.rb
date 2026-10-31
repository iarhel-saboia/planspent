# Puts money aside for a goal ("Guardar") or takes it back ("Resgatar")
class GoalContributionsController < ApplicationController
  def create
    @goal = Goal.find(params[:goal_id])
    attributes = params.expect(contribution: %i[amount occurred_on kind])
    withdrawal = attributes[:kind] == "withdrawal"
    @entry = @goal.contribute(amount: attributes[:amount], occurred_on: attributes[:occurred_on], withdrawal: withdrawal)

    if @entry.persisted?
      notice = withdrawal ? "Valor resgatado da meta." : "Valor guardado na meta!"
      notice = "Parabéns, você atingiu a meta #{@goal.name}!" if !withdrawal && @goal.reload.completed?
      redirect_back_or_to goals_path, notice: notice
    else
      render turbo_stream: turbo_stream.replace(helpers.contribution_form_id(@goal, withdrawal),
        partial: "goals/contribution_form", locals: { goal: @goal, entry: @entry, withdrawal: withdrawal }),
        status: :unprocessable_content
    end
  end
end
