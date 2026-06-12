require "csv"

module Briefs
  # Exports a brief analysis as a table of authorities (CSV or minimal DOCX).
  class ToaExporter
    HEADERS = ["Authority", "Citation", "Pin Cite", "Type", "Status", "Treatment", "Matched Title"].freeze

    def initialize(analysis)
      @analysis = analysis
    end

    def to_csv
      CSV.generate do |csv|
        csv << HEADERS
        rows.each { |row| csv << row }
      end
    end

    # A deliberately minimal WordprocessingML document: one table, no
    # styling dependencies, openable by Word/LibreOffice/Pages.
    def to_docx
      buffer = Zip::OutputStream.write_buffer do |zip|
        zip.put_next_entry("[Content_Types].xml")
        zip.write(content_types_xml)
        zip.put_next_entry("_rels/.rels")
        zip.write(rels_xml)
        zip.put_next_entry("word/document.xml")
        zip.write(document_xml)
      end
      buffer.string
    end

    private

    def rows
      @analysis.brief_citations.map do |bc|
        [
          bc.document&.title || bc.raw_cite,
          bc.raw_cite,
          bc.pin_cite,
          bc.kind.humanize,
          bc.authority_status.titleize,
          bc.matched? ? Citator::TreatmentResolver.badge_for(bc.treatment_status)[:label] : "—",
          bc.document&.display_citation
        ]
      end
    end

    def document_xml
      table_rows = ([HEADERS] + rows).map do |cells|
        cells_xml = cells.map do |cell|
          "<w:tc><w:p><w:r><w:t xml:space=\"preserve\">#{escape(cell)}</w:t></w:r></w:p></w:tc>"
        end.join
        "<w:tr>#{cells_xml}</w:tr>"
      end.join

      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>Table of Authorities — #{escape(@analysis.uploaded_document.title)}</w:t></w:r></w:p>
            <w:tbl>#{table_rows}</w:tbl>
            <w:p/>
          </w:body>
        </w:document>
      XML
    end

    def content_types_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml"
                    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
      XML
    end

    def rels_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1"
                        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
                        Target="word/document.xml"/>
        </Relationships>
      XML
    end

    def escape(value)
      ERB::Util.xml_escape(value.to_s)
    end
  end
end
