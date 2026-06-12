class ResearchController < ApplicationController
  # The main three-pane research workspace: results list, document pane,
  # refine rail. Panes are independent turbo frames.
  def index
    @query = params[:q].to_s.strip
    @sort = params[:sort].presence_in(%w[relevance date cited]) || "relevance"
    @filters = Search::Filters.normalize(params)
    @page = params[:page].to_i.clamp(1, 500)

    if @query.present?
      @results = Search::Engine.new.call(q: @query, filters: @filters, page: @page, sort: @sort)
      record_history
    end

    @selected_document = Document.find_by(slug: params[:doc]) if params[:doc].present?
    @selected_document ||= @results&.entries&.first&.document
    prepare_document_pane if @selected_document

    @saved_folders = current_user.visible_folders.kept.order(updated_at: :desc).limit(6)
  end

  private

  def record_history
    return if @page > 1 || params[:doc].present? # only log fresh searches

    history = current_user.search_histories.recent_first.first
    return if history&.query == @query && history.created_at > 1.minute.ago

    current_user.search_histories.create!(
      query: @query, query_type: @results.query_type,
      filters: @filters, results_count: @results.total
    )
  end

  def prepare_document_pane
    @tab = params[:tab].presence_in(%w[overview opinion notes citing outline]) || "overview"
    @treatment_counts = Citator::TreatmentResolver.summary_counts(@selected_document)
    @notes = @selected_document.notes_for(current_user)
    @pinned = current_user.pins.exists?(document: @selected_document)
    @document_view = DocumentView.record!(current_user, @selected_document)
    @suggestions = Search::VectorAdapter.new.more_like(@selected_document, limit: 3)
  end
end
