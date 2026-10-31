module GoalsHelper
  STATUSES = {
    completed: [ "Concluída", "bg-indigo-50 dark:bg-indigo-500/15 text-indigo-700 dark:text-indigo-300" ],
    on_track: [ "No ritmo", "bg-emerald-50 dark:bg-emerald-500/15 text-emerald-700 dark:text-emerald-300" ],
    behind: [ "Atrasada", "bg-amber-50 dark:bg-amber-500/15 text-amber-700 dark:text-amber-300" ],
    overdue: [ "Prazo vencido", "bg-rose-50 dark:bg-rose-500/15 text-rose-700 dark:text-rose-300" ],
    no_deadline: [ "Sem prazo", "bg-surface-muted text-fg-muted" ]
  }.freeze

  def goal_status_badge(goal)
    label, classes = STATUSES.fetch(goal.status)
    tag.span(label, class: "inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium #{classes}")
  end

  # "dez/2027 · 15 meses"
  def goal_deadline(goal)
    return "Sem prazo definido" unless goal.target_date

    months = goal.months_left
    left = months.zero? ? "prazo vencido" : pluralize(months, "mês", plural: "meses")
    "Até #{l(goal.target_date, format: '%b/%Y').downcase} · #{left}"
  end

  # What the user typed after a validation error, otherwise the stored value as "1.234,56"
  def decimal_field_value(record, attribute)
    return record.read_attribute_before_type_cast(attribute) if record.errors.any?

    value = record.public_send(attribute)
    number_with_precision(value, precision: 2, separator: ",", delimiter: ".") if value
  end

  # "20% do que entra" or "R$ 1.000,00"
  def monthly_goal_target(goal)
    goal.target_percent ? "#{number_with_precision(goal.target_percent, precision: 2, strip_insignificant_zeros: true, separator: ',')}% do que entra" : brl(goal.target_amount)
  end

  # Savings goals offered when linking an entry
  def savings_goal_options
    @savings_goal_options ||= Goal.savings.by_creation.pluck(:name, :id)
  end

  def goal_form_id(goal)
    goal.persisted? ? dom_id(goal, :form) : "new_#{goal.kind}_goal_form"
  end

  def goal_modal_id(goal)
    goal.persisted? ? dom_id(goal, :edit_modal) : "new_#{goal.kind}_goal_modal"
  end

  def contribution_form_id(goal, withdrawal)
    dom_id(goal, withdrawal ? :withdrawal_form : :contribution_form)
  end

  def contribution_modal_id(goal, withdrawal)
    dom_id(goal, withdrawal ? :withdrawal_modal : :contribution_modal)
  end
end
