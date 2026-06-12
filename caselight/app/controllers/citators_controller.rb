class CitatorsController < ApplicationController
  # Citation lookup landing ("Citations" section).
  def index
    @query = params[:q].to_s.strip
    return if @query.blank?

    @document = Document.find_by_citation(@query)
    if @document
      redirect_to document_citator_path(@document)
    else
      @miss = true
      @suggestions = Search::Engine.new.call(q: @query, per: 5).entries
    end
  end

  # Treatment history + citing-references analysis for one authority.
  def show
    @document = Document.find_by!(slug: params[:document_slug])
    @counts = Citator::TreatmentResolver.summary_counts(@document)

    refs = @document.inbound_references.includes(citing_document: :court)
    @classification = params[:classification].presence_in(%w[positive cautionary negative])
    @depth = params[:depth].presence_in(CitingReference.depths.keys)
    refs = refs.where(treatment: CitingReference.treatments_for(@classification)) if @classification
    refs = refs.where(depth: @depth) if @depth
    if params[:jurisdiction_id].present?
      refs = refs.joins(:citing_document).where(documents: { jurisdiction_id: params[:jurisdiction_id] })
    end
    @citing_references = refs.joins(:citing_document)
                             .order(Arel.sql("documents.decided_on DESC NULLS LAST"))
                             .limit(200)
    @jurisdictions = Jurisdiction.where(
      id: @document.citing_documents.select(:jurisdiction_id).distinct
    ).order(:name)
    @cited = @document.outbound_references.includes(cited_document: :court).limit(50)
  end

  # JSON for the interactive citing-references graph.
  def graph
    document = Document.find_by!(slug: params[:document_slug])
    refs = document.inbound_references.includes(citing_document: :court).limit(120)
    render json: {
      center: { id: document.id, title: document.title.truncate(48), citation: document.display_citation,
                treatment: document.treatment_status },
      nodes: refs.map do |ref|
        doc = ref.citing_document
        { id: doc.id, title: doc.title.truncate(40), citation: doc.display_citation,
          year: doc.decided_on&.year, treatment: ref.treatment,
          classification: ref.classification, depth: ref.depth,
          url: document_path(doc) }
      end
    }
  end
end
