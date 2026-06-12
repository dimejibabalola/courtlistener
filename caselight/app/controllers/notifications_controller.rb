class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.recent_first.limit(50)
    respond_to do |format|
      format.html
      format.turbo_stream { render partial: "notifications/menu", locals: { notifications: @notifications.first(8) } }
    end
  end

  def mark_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!
    redirect_back_or_to notifications_path
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back_or_to notifications_path, notice: "All alerts marked read."
  end
end
