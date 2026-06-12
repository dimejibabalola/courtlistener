class HistoryController < ApplicationController
  # Unified, resumable research timeline: searches and document views.
  def index
    searches = current_user.search_histories.recent_first.limit(200).map do |h|
      { kind: :search, at: h.created_at, record: h }
    end
    views = current_user.document_views.includes(document: :court).recent_first.limit(200).map do |v|
      { kind: :view, at: v.last_viewed_at, record: v }
    end
    @entries = (searches + views).sort_by { |e| e[:at] }.reverse.first(250)
    @by_day = @entries.group_by { |e| e[:at].to_date }
  end

  def clear
    current_user.search_histories.delete_all
    current_user.document_views.delete_all
    redirect_to history_path, notice: "History cleared."
  end
end
