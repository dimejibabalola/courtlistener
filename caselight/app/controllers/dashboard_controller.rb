class DashboardController < ApplicationController
  def show
    @recent_searches = current_user.search_histories.recent_first.limit(6)
    @recent_views = current_user.document_views.includes(document: :court).recent_first.limit(6)
    @pinned = current_user.pins.includes(document: :court).order(:position, :created_at).limit(6)
    @matters = current_user.visible_matters.kept.order(updated_at: :desc).limit(4)
    @alerts = current_user.notifications.recent_first.limit(5)
    @saved_searches = current_user.saved_searches.order(updated_at: :desc).limit(5)
  end
end
