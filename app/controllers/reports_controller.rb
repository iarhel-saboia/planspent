class ReportsController < ApplicationController
  def index
    @reports = Entry.monthly_balances(before: Date.current.beginning_of_month)
  end
end
