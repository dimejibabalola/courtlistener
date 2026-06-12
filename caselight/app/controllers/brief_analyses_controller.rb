class BriefAnalysesController < ApplicationController
  before_action :set_upload

  def create
    analysis = @upload.brief_analyses.create!(user: current_user)
    Briefs::AnalyzeJob.perform_later(analysis.id)
    redirect_to upload_brief_analysis_path(@upload, analysis), notice: "Analyzing authorities…"
  end

  def show
    @analysis = @upload.brief_analyses.find(params[:id])
    @status_filter = params[:status].presence_in(%w[clean cautionary negative unmatched])
    @citations = @analysis.brief_citations.includes(document: :court)
    @citations = filter_citations(@citations) if @status_filter
  end

  def export
    @analysis = @upload.brief_analyses.find(params[:id])
    exporter = Briefs::ToaExporter.new(@analysis)
    basename = "table-of-authorities-#{@upload.title.parameterize}"
    respond_to do |format|
      format.csv { send_data exporter.to_csv, filename: "#{basename}.csv", type: "text/csv" }
      format.docx do
        send_data exporter.to_docx, filename: "#{basename}.docx",
                  type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      end
      format.any { redirect_to upload_brief_analysis_path(@upload, @analysis, format: nil) }
    end
  end

  private

  def set_upload
    @upload = current_user.uploaded_documents.find(params[:upload_id])
  end

  def filter_citations(citations)
    case @status_filter
    when "unmatched" then citations.where.not(status: :matched)
    when "negative" then citations.matched.where(treatment_status: :negative)
    when "cautionary" then citations.matched.where(treatment_status: :cautionary)
    else citations.matched.where(treatment_status: [:untreated, :positive])
    end
  end
end
