class ImportsController < ApplicationController
  def new
  end

  # Analyzes the uploaded statement and shows the detected transactions for review (nothing is saved yet)
  def create
    file = params[:statement]
    return render_upload_error("Selecione o arquivo do extrato.") unless file.respond_to?(:content_type)

    entries = StatementParser.call(file, password: params[:password]).map { |transaction| Entry.new(transaction.to_h) }
    return render_upload_error("Nenhuma transação foi encontrada neste arquivo.") if entries.empty?

    suggest_goals(entries)

    duplicates = duplicate_indexes(entries)
    # Possible duplicates start unchecked
    render_review(entries, entries.each_index.to_a - duplicates, nil, status: :ok)
  rescue StatementParser::Error => e
    render_upload_error(e.message)
  end

  # Saves the transactions the user kept selected on the review screen
  def confirm
    # The form posts entries[0][...], entries[1][...]; keep them in their on-screen order
    rows = params.expect(entries: [ [ :selected, :occurred_on, :description, :amount, :kind, :goal_id ] ])
    rows = rows.to_h.sort_by { |index, _| index.to_i }.map(&:last) unless rows.is_a?(Array)
    savings_goal_ids = Goal.savings.ids.map(&:to_s)
    rows.each { |row| row[:goal_id] = nil unless row[:goal_id].in?(savings_goal_ids) }
    selected = rows.each_index.select { |i| rows[i][:selected] == "1" }
    entries = rows.map { |row| Entry.new(row.except(:selected)) }
    chosen = selected.map { |i| entries[i] }

    if chosen.empty?
      render_review(entries, selected, "Selecione ao menos um lançamento para importar.")
    elsif chosen.all?(&:valid?)
      Entry.transaction { chosen.each(&:save!) }
      latest = chosen.map(&:occurred_on).max
      notice = "#{chosen.size} #{chosen.size == 1 ? 'lançamento importado' : 'lançamentos importados'}!"
      linked = chosen.count(&:goal_id)
      notice += " #{linked} #{linked == 1 ? 'vinculado' : 'vinculados'} a metas." if linked.positive?
      redirect_to root_path(month: latest.strftime("%Y-%m")), notice: notice
    else
      render_review(entries, selected, "Corrija os lançamentos destacados antes de importar.")
    end
  end

  private

  def render_upload_error(message)
    render turbo_stream: turbo_stream.update("import", partial: "imports/upload_form", locals: { error: message }),
      status: :unprocessable_content
  end

  def render_review(entries, selected, error, status: :unprocessable_content)
    render turbo_stream: turbo_stream.update("import", partial: "imports/review",
      locals: { entries: entries, duplicates: duplicate_indexes(entries), selected: selected, error: error }),
      status: status
  end

  # Pre-selects the goal of earlier entries with the same description (e.g. a monthly "Aplicação CDB")
  def suggest_goals(entries)
    linked = Entry.joins(:goal).merge(Goal.savings).order(:occurred_on).pluck(:description, :goal_id)
      .to_h { |description, goal_id| [ MerchantCategory.pattern_for(description), goal_id ] }
    linked.delete("")
    entries.each { |entry| entry.goal_id = linked[MerchantCategory.pattern_for(entry.description)] }
  end

  # Indexes of rows that match an existing entry (same date, amount and kind)
  def duplicate_indexes(entries)
    existing = Entry.where(occurred_on: entries.filter_map(&:occurred_on))
      .pluck(:occurred_on, :amount, :kind)
      .to_set
    entries.each_index.select { |i| existing.include?([ entries[i].occurred_on, entries[i].amount, entries[i].kind ]) }
  end
end
