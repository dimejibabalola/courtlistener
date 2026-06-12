module Ingest
  # Importers normalize external corpora into the Document model and hand
  # each record to Ingest::Pipeline (via IngestDocumentJob). Subclasses
  # implement #each_record, yielding normalized attribute hashes:
  #
  #   { type:, title:, citations: ["..."], court_slug:, jurisdiction_slug:,
  #     decided_on:, docket_number:, full_text:, source_url:, source_name: }
  class BaseImporter
    def import!
      imported = []
      each_record do |attributes|
        document = upsert(attributes)
        IngestDocumentJob.perform_later(document.id)
        imported << document
      end
      imported
    end

    private

    def each_record
      raise NotImplementedError
    end

    def upsert(attributes)
      citations = Array(attributes.delete(:citations))
      court = Court.find_by(slug: attributes.delete(:court_slug))
      jurisdiction = Jurisdiction.find_by(slug: attributes.delete(:jurisdiction_slug)) || court&.jurisdiction

      document = find_existing(citations, attributes) || Document.new
      document.assign_attributes(
        attributes.merge(
          court:, jurisdiction:,
          primary_citation: attributes[:primary_citation] || citations.first
        )
      )
      document.save!
      citations.each do |raw|
        document.citations.find_or_create_by!(normalized: Citation.normalize(raw)) { |c| c.raw = raw }
      end
      document
    end

    def find_existing(citations, attributes)
      citations.each do |raw|
        if (existing = Citation.lookup(raw)&.document)
          return existing
        end
      end
      Document.find_by(source_url: attributes[:source_url]) if attributes[:source_url].present?
    end
  end
end
