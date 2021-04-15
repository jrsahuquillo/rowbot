class ApplicationController < ActionController::Base
  def redirect_user
    redirect_to '/404'
  end
end
