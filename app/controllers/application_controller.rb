class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def after_sign_in_path_for(resource)
    root_path
  end

  def after_sign_up_path_for(resource)
    root_path
  end

  def configure_permitted_parameters
    # Allow name on sign up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])

    # Allow name on account update (optional)
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end
end