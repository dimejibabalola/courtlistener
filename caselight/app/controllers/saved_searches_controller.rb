class SavedSearchesController < ApplicationController
  def index
    @saved_searches = current_user.saved_searches.order(updated_at: :desc)
  end

  def create
    saved = current_user.saved_searches.create!(
      name: params[:name].presence || params[:query].to_s.truncate(60),
      query: params[:query],
      filters: Search::Filters.normalize(params),
      alerts_enabled: params[:alerts_enabled] == "1"
    )
    SavedSearchAlertsJob.perform_later(saved.id) if saved.alerts_enabled?
    redirect_back_or_to research_path(q: saved.query), notice: "Search saved#{saved.alerts_enabled? ? ' with alerts' : ''}."
  end

  def destroy
    current_user.saved_searches.find(params[:id]).destroy!
    redirect_back_or_to saved_searches_path, notice: "Saved search removed."
  end

  def toggle_alerts
    saved = current_user.saved_searches.find(params[:id])
    saved.update!(alerts_enabled: !saved.alerts_enabled)
    redirect_back_or_to saved_searches_path
  end
end
