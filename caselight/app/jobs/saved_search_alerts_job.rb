# Re-runs alert-enabled saved searches and notifies their owners of new
# hits. Schedule periodically (e.g. hourly via cron/sidekiq-scheduler):
#   SavedSearchAlertsJob.perform_later
class SavedSearchAlertsJob < ApplicationJob
  queue_as :alerts

  def perform(saved_search_id = nil)
    scope = saved_search_id ? SavedSearch.where(id: saved_search_id) : SavedSearch.alertable
    scope.find_each { |saved_search| run_one(saved_search) }
  end

  private

  def run_one(saved_search)
    results = Search::Engine.new.call(q: saved_search.query, filters: saved_search.filters, per: 50)
    result_ids = results.entries.map { |e| e.document.id }
    new_ids = saved_search.new_result_ids(result_ids)
    saved_search.record_run!(result_ids)
    return if new_ids.empty? || saved_search.last_run_at.nil?

    saved_search.user.notifications.create!(
      kind: :saved_search_alert,
      title: "#{new_ids.size} new #{'result'.pluralize(new_ids.size)} for “#{saved_search.name}”",
      body: Document.where(id: new_ids.first(3)).pluck(:title).join("; "),
      url: Rails.application.routes.url_helpers.research_path(q: saved_search.query),
      payload: { saved_search_id: saved_search.id, new_document_ids: new_ids.first(50) }
    )
  end
end
