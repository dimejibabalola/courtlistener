class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :configure_devise_params, if: :devise_controller?

  helper_method :unread_alerts_count

  private

  def unread_alerts_count
    @unread_alerts_count ||= current_user&.unread_notifications_count.to_i
  end

  def configure_devise_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:full_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:full_name])
  end
end
