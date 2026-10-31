class PlaceholdersController < ApplicationController
  def show
    @item = helpers.navigation_items.find { |item| item[:page] == params[:page] } || raise(ActionController::RoutingError, "Not Found")
  end
end
