class DocumentsController < ApplicationController
  before_action :set_document

  def show
    @tab = params[:tab].presence_in(%w[overview opinion notes citing outline]) || "overview"
    @treatment_counts = Citator::TreatmentResolver.summary_counts(@document)
    @notes = @document.notes_for(current_user)
    @pinned = current_user.pins.exists?(document: @document)
    DocumentView.record!(current_user, @document)
  end

  def pin
    current_user.pins.create_or_find_by!(document: @document)
    redirect_back_or_to document_path(@document), notice: "Pinned #{@document.title.truncate(60)}."
  end

  def unpin
    current_user.pins.where(document: @document).destroy_all
    redirect_back_or_to document_path(@document), notice: "Unpinned."
  end

  # Citation formats panel (copy-with-citation)
  def cite
    render partial: "documents/cite", locals: { document: @document }
  end

  def download
    text = <<~TEXT
      #{@document.title}
      #{@document.display_citation}
      #{@document.court_line}

      #{@document.reading_text}
    TEXT
    send_data text, filename: "#{@document.slug}.txt", type: "text/plain"
  end

  private

  def set_document
    @document = Document.find_by!(slug: params[:slug] || params[:document_slug])
  end
end
