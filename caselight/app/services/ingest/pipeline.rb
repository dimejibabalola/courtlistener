module Ingest
  # Post-ingest processing for one document: full-text/vector indexing,
  # citation edge extraction, and incremental treatment recompute for every
  # authority the new document touches.
  class Pipeline
    def self.process!(document)
      new(document).process!
    end

    def initialize(document)
      @document = document
    end

    def process!
      Search::Indexer.new(@document).run!
      edges = Citator::EdgeBuilder.new(@document).run!
      edges.each { |edge| Citator::TreatmentResolver.new(edge.cited_document).resolve! }
      @document
    end
  end
end
