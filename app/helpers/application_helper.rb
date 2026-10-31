module ApplicationHelper
  def dark_mode?
    cookies[:theme] == "dark"
  end
end
