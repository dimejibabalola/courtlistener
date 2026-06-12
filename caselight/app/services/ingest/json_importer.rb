module Ingest
  # Imports documents from a directory of JSON files (one document per file
  # or an array per file) — the bulk-corpus path.
  class JsonImporter < BaseImporter
    def initialize(path)
      @path = Pathname(path)
    end

    private

    def each_record
      Dir.glob(@path.join("**/*.json")).sort.each do |file|
        payload = JSON.parse(File.read(file))
        Array.wrap(payload).each do |record|
          yield normalize(record)
        end
      end
    end

    def normalize(record)
      {
        type: record.fetch("type", "Case"),
        title: record.fetch("title"),
        citations: record.fetch("citations", []),
        court_slug: record["court"],
        jurisdiction_slug: record["jurisdiction"],
        decided_on: record["decided_on"],
        docket_number: record["docket_number"],
        full_text: record["full_text"],
        summary: record["summary"],
        source_url: record["source_url"],
        source_name: record.fetch("source_name", "json-import")
      }
    end
  end
end
