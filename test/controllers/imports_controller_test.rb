require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  def statement(name = "extrato.ofx")
    fixture_file_upload(name, "application/octet-stream")
  end

  test "shows the upload page and the sidebar item" do
    get new_import_path
    assert_response :success
    assert_select "input[type=file][name=statement]"
    assert_select "aside nav a[aria-current=page][aria-label='Importar extrato']"
  end

  test "reading a statement shows the transactions for review, with duplicates unchecked" do
    Entry.create!(description: "Aluguel", amount: 1500, kind: :debit, occurred_on: Date.new(2026, 9, 7))

    assert_no_difference("Entry.count") { post imports_path, params: { statement: statement }, as: :turbo_stream }

    assert_response :success
    assert_match "Salário ACME", response.body
    assert_match(/id="entries_0_selected"[^>]*checked="checked"/, response.body)
    assert_no_match(/id="entries_2_selected"[^>]*checked="checked"/, response.body)
    assert_match "Possível duplicado", response.body
  end

  test "unsupported files show an error on the upload form" do
    post imports_path, params: { statement: Rack::Test::UploadedFile.new(StringIO.new("PK"), "application/zip", original_filename: "extrato.docx") },
      as: :turbo_stream
    assert_response :unprocessable_content
    assert_match "Formato não suportado", response.body
  end

  test "reads PDF statements" do
    post imports_path, params: { statement: statement("extrato.pdf") }, as: :turbo_stream
    assert_response :success
    assert_match "Aluguel setembro", response.body
  end

  test "confirming imports only the selected rows" do
    params = { entries: {
      "0" => { selected: "1", occurred_on: "2026-09-03", description: "Salário ACME", amount: "4.200,00", kind: "credit" },
      "1" => { selected: "0", occurred_on: "2026-09-04", description: "Ignorar", amount: "10,00", kind: "debit" },
      "2" => { selected: "1", occurred_on: "2026-09-05", description: "Farmácia", amount: "35,90", kind: "debit" }
    } }

    assert_difference("Entry.count", 2) { post confirm_import_path, params: params }
    assert_redirected_to root_path(month: "2026-09")
    assert_equal BigDecimal("4200"), Entry.find_by(description: "Salário ACME").amount
    assert_nil Entry.find_by(description: "Ignorar")
    assert_equal categories(:salary), Entry.find_by(description: "Salário ACME").category
  end

  test "confirming with an invalid selected row saves nothing and highlights the problem" do
    params = { entries: {
      "0" => { selected: "1", occurred_on: "2026-09-03", description: "Ok", amount: "10,00", kind: "debit" },
      "1" => { selected: "1", occurred_on: "2026-09-04", description: "", amount: "10,00", kind: "debit" }
    } }

    assert_no_difference("Entry.count") { post confirm_import_path, params: params, as: :turbo_stream }
    assert_response :unprocessable_content
    assert_match "Descrição não pode ficar em branco", response.body
  end

  test "review offers the savings goals and suggests the goal of earlier entries with the same description" do
    Entry.create!(description: "Aluguel setembro", amount: 100, kind: :debit, occurred_on: Date.new(2025, 9, 7), goal: goals(:trip))

    post imports_path, params: { statement: statement }, as: :turbo_stream

    html = Nokogiri::HTML(response.body)
    chosen = ->(i) { html.at_css("select[name='entries[#{i}][goal_id]'] option[selected]")&.text }
    assert_nil chosen.(0)
    assert_equal "Viagem", chosen.(2)
    assert_not_includes html.css("select[name='entries[0][goal_id]'] option").map(&:text), "Guardar todo mês"
  end

  test "confirming links the chosen rows to goals, ignoring unknown or monthly goals" do
    params = { entries: {
      "0" => { selected: "1", occurred_on: "2026-09-03", description: "Aplicação CDB", amount: "300,00", kind: "debit", goal_id: goals(:trip).id },
      "1" => { selected: "1", occurred_on: "2026-09-04", description: "Farmácia", amount: "10,00", kind: "debit", goal_id: goals(:save_monthly).id },
      "2" => { selected: "1", occurred_on: "2026-09-05", description: "Padaria", amount: "5,00", kind: "debit", goal_id: "999999" }
    } }

    assert_difference("Entry.count", 3) { post confirm_import_path, params: params }
    assert_equal "3 lançamentos importados! 1 vinculado a metas.", flash[:notice]
    assert_equal goals(:trip), Entry.find_by(description: "Aplicação CDB").goal
    assert_nil Entry.find_by(description: "Farmácia").goal
    assert_nil Entry.find_by(description: "Padaria").goal
  end
end
