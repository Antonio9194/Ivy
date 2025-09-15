class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # Allow full_name on sign up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:full_name])

    # Allow full_name on account update (optional)
    devise_parameter_sanitizer.permit(:account_update, keys: [:full_name])
  end
end