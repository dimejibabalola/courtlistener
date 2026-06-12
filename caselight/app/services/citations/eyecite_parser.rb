require "open3"

module Citations
  # Citation recognition backed by eyecite (the Free Law Project's parser,
  # the same library CourtListener uses), via lib/python/extract_citations.py.
  # Emits the same Found structs as the pure-Ruby Citations::Parser so the
  # two backends are interchangeable.
  class EyeciteParser
    class Error < StandardError; end

    SCRIPT = Rails.root.join("lib/python/extract_citations.py").to_s
    PYTHON = ENV.fetch("PYTHON_BIN", "python3")

    class << self
      def available?
        return @available unless @available.nil?

        @available = begin
          _out, _err, status = Open3.capture3(PYTHON, "-c", "import eyecite")
          status.success?
        rescue Errno::ENOENT
          false
        end
      end

      def reset! = @available = nil

      def parse(text)
        new(text).parse
      end
    end

    def initialize(text)
      @text = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
    end

    def parse
      stdout, stderr, status = Open3.capture3(PYTHON, SCRIPT, stdin_data: @text)
      raise Error, "eyecite shim failed: #{stderr.presence || status.exitstatus}" unless status.success?

      rows = JSON.parse(stdout)
      build_found(rows)
    rescue JSON::ParserError => e
      raise Error, "eyecite shim returned invalid JSON: #{e.message}"
    rescue Errno::ENOENT => e
      raise Error, "python interpreter not found: #{e.message}"
    end

    private

    def build_found(rows)
      found = rows.map { |row| to_found(row) }
      rows.each_with_index do |row, i|
        next if row["resolved_index"].nil?

        found[i].resolved_from = found[row["resolved_index"]]
        found[i].normalized ||= found[i].resolved_from&.normalized
      end
      found
    end

    def to_found(row)
      kind = row["kind"].to_sym
      Parser::Found.new(
        raw: row["raw"],
        kind: kind,
        case_name: row["case_name"],
        volume: row["volume"]&.to_i,
        reporter: row["reporter"],
        page: row["page"]&.to_i,
        pin_cite: row["pin_cite"],
        section: row["section"],
        position: row["position"].to_i,
        normalized: normalized_for(kind, row),
        court_year: row["year"]&.to_i
      )
    end

    def normalized_for(kind, row)
      case kind
      when :case_full
        Citation.normalize("#{row['volume']} #{row['reporter']} #{row['page']}")
      when :statute, :regulation
        if row["title"].present? && row["section"].present?
          Citation.normalize("#{row['title']} #{row['reporter']} § #{row['section']}")
        else
          Citation.normalize(row["raw"])
        end
      end
    end
  end
end
