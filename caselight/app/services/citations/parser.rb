module Citations
  # Citation recognizer: finds case reporter citations (full and short form),
  # statutes, and regulations in running text, and resolves short forms
  # (id. / supra / "<Party>, 987 F.3d at 1241") back to the first full cite.
  class Parser
    Found = Struct.new(
      :raw, :kind, :case_name, :volume, :reporter, :page, :pin_cite,
      :section, :position, :normalized, :resolved_from, :court_year,
      keyword_init: true
    ) do
      def full? = %i[case_full statute regulation].include?(kind)
      def short_form? = %i[case_short id_cite supra_cite].include?(kind)
    end

    # Common public reporter abbreviations (longest-first so alternation
    # prefers the most specific match).
    REPORTERS = [
      "L. Ed. 2d", "L. Ed.", "S. Ct.", "U.S.",
      "F. Supp. 3d", "F. Supp. 2d", "F. Supp.", "F. App'x", "F.R.D.",
      "F.4th", "F.3d", "F.2d", "B.R.",
      "A.3d", "A.2d", "P.3d", "P.2d",
      "N.E.3d", "N.E.2d", "N.W.3d", "N.W.2d",
      "S.E.2d", "S.E.", "S.W.3d", "S.W.2d",
      "So. 3d", "So. 2d",
      "Cal. Rptr. 3d", "Cal. Rptr. 2d", "Cal. Rptr.",
      "Cal. App. 5th", "Cal. App. 4th", "Cal. App. 3d", "Cal. App. 2d", "Cal. App.",
      "Cal. 5th", "Cal. 4th", "Cal. 3d", "Cal. 2d",
      "N.Y.S.3d", "N.Y.S.2d", "N.Y.3d", "N.Y.2d",
      "Ohio St. 3d", "Ill. 2d", "Ill. App. 3d", "Mass.", "Wis. 2d", "Wash. 2d",
      "N.C. App.", "N.J.", "Pa.", "Tex.", "Vt.", "F."
    ].freeze

    REPORTER_ALTERNATION = REPORTERS.map { |r|
      Regexp.escape(r).gsub('\.', '\.\s?').gsub('\ ', '\s?')
    }.join("|").freeze

    CASE_NAME_TAIL = /
      (?<name>
        (?:In\sre|Ex\sparte|Matter\sof)\s+[A-Z][\w.,'’&()\- ]{2,80}?
        |
        [A-Z][\w.,'’&()\-]*(?:\s[\w.,'’&()\-]+){0,8}?\s+v\.\s+[A-Z][\w.,'’&()\-]*(?:\s[\w.,'’&()\-]+){0,8}?
      )
      ,?\s*\z
    /x

    FULL_CASE = /
      (?<volume>\d{1,4})\s
      (?<reporter>#{REPORTER_ALTERNATION})\s?
      (?<page>\d{1,5})\b
      (?:,\s?(?<pin>\d{1,5}(?:[-–]\d{1,5})?))?
      (?:\s?\((?<paren>[^()]{0,60}?(?<year>\d{4}))\))?
    /x

    SHORT_CASE = /
      (?<name>[A-Z][\w.'’\-]+(?:\s[A-Z][\w.'’\-]+)?),\s
      (?<volume>\d{1,4})\s
      (?<reporter>#{REPORTER_ALTERNATION})\s
      at\s(?<pin>\d{1,5}(?:[-–]\d{1,5})?)
    /x

    ID_CITE = /\b(?<id>Id\.|id\.)(?:\sat\s(?<pin>\d{1,5}(?:[-–]\d{1,5})?))?/

    SUPRA_CITE = /
      (?<name>[A-Z][\w.'’\-]+(?:\s[A-Z][\w.'’\-]+)?),\s
      supra
      (?:,?\s(?:note\s\d+)?,?\s?(?:at\s(?<pin>\d{1,5}(?:[-–]\d{1,5})?))?)?
    /x

    STATUTE = /
      (?<title>\d{1,3})\s
      U\.\s?S\.\s?C\.(?:\s?A\.)?\s?
      §{1,2}\s?
      (?<section>\d[\w.\-()]*)
    /x

    REGULATION = /
      (?<title>\d{1,3})\s
      C\.\s?F\.\s?R\.\s?
      §{0,2}\s?
      (?<section>\d[\w.\-]*?)(?=[\s,;)]|\.\s|\z)
    /x

    def self.parse(text) = new(text).parse

    # Anything allowed to precede the citation in a citation-only query:
    # nothing, a signal ("See"), or a case name.
    QUERY_PREFIX = /
      \A(?:see\s+|cf\.\s+|accord\s+)?
      (?:
        (?:in\s+re|ex\s+parte|matter\s+of)\s+[\w.,'’&()\- ]{2,80}
        |
        [\w.'’&()\-]+(?:\s+[\w.,'’&()\-]+){0,8}\s+v\.\s+[\w.,'’&()\- ]{1,80}
      )?
      [,:]?\s*\z
    /ix

    # True when the string is, in substance, a single citation — used by the
    # query planner to route citation lookups.
    def self.citation_query?(text)
      stripped = text.to_s.strip
      return false if stripped.blank?

      [FULL_CASE, STATUTE, REGULATION].any? do |re|
        m = re.match(stripped)
        next false unless m

        prefix = stripped[0...m.begin(0)]
        suffix = stripped[(m.begin(0) + m[0].length)..].to_s
        QUERY_PREFIX.match?(prefix) && suffix.strip.length <= 2
      end
    end

    def initialize(text)
      @text = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
    end

    def parse
      found = scan_all
      resolve_short_forms(found)
      found
    end

    private

    def scan_all
      matches = []
      scan(FULL_CASE) do |m|
        matches << build_full_case(m)
      end
      scan(STATUTE) do |m|
        matches << Found.new(
          raw: m[0].strip, kind: :statute, section: m[:section], position: m.begin(0),
          normalized: Citation.normalize("#{m[:title]} U.S.C. § #{m[:section]}")
        )
      end
      scan(REGULATION) do |m|
        matches << Found.new(
          raw: m[0].strip, kind: :regulation, section: m[:section], position: m.begin(0),
          normalized: Citation.normalize("#{m[:title]} C.F.R. § #{m[:section]}")
        )
      end
      scan(SHORT_CASE) do |m|
        matches << Found.new(
          raw: m[0].strip, kind: :case_short, case_name: m[:name], volume: m[:volume].to_i,
          reporter: canonical_reporter(m[:reporter]), pin_cite: m[:pin], position: m.begin(0)
        )
      end
      scan(ID_CITE) do |m|
        matches << Found.new(raw: m[0].strip, kind: :id_cite, pin_cite: m[:pin], position: m.begin(0))
      end
      scan(SUPRA_CITE) do |m|
        matches << Found.new(
          raw: m[0].strip, kind: :supra_cite, case_name: m[:name],
          pin_cite: m[:pin], position: m.begin(0)
        )
      end
      dedupe_overlaps(matches.sort_by!(&:position))
    end

    def scan(regexp)
      @text.scan(regexp) { yield Regexp.last_match }
    end

    def build_full_case(m)
      reporter = canonical_reporter(m[:reporter])
      raw_core = "#{m[:volume]} #{reporter} #{m[:page]}"
      Found.new(
        raw: m[0].strip,
        kind: :case_full,
        case_name: case_name_before(m.begin(0)),
        volume: m[:volume].to_i,
        reporter: reporter,
        page: m[:page].to_i,
        pin_cite: m[:pin],
        position: m.begin(0),
        normalized: Citation.normalize(raw_core),
        court_year: m.names.include?("year") ? m[:year]&.to_i : nil
      )
    end

    # Normalize whitespace/punctuation variants back to the canonical
    # reporter abbreviation ("F. 3d" -> "F.3d").
    def canonical_reporter(matched)
      squeezed = matched.gsub(/\s+/, "")
      REPORTERS.find { |r| r.gsub(/\s+/, "") == squeezed } || matched.strip
    end

    def case_name_before(position)
      window = @text[[position - 140, 0].max...position]
      CASE_NAME_TAIL.match(window)&.[](:name)&.strip
    end

    # Full cites win over short forms occupying the same span; earlier and
    # longer matches win ties.
    def dedupe_overlaps(matches)
      kept = []
      matches.each do |m|
        overlapping = kept.find { |k| spans_overlap?(k, m) }
        next if overlapping && precedence(overlapping) >= precedence(m)

        kept.delete(overlapping) if overlapping
        kept << m
      end
      kept.sort_by(&:position)
    end

    def spans_overlap?(a, b)
      a_range = a.position...(a.position + a.raw.length)
      b_range = b.position...(b.position + b.raw.length)
      a_range.cover?(b.position) || b_range.cover?(a.position)
    end

    def precedence(found)
      found.full? ? 2 : 1
    end

    # Walk the matches in order, resolving id./supra/short cites back to the
    # most recent compatible full cite.
    def resolve_short_forms(found)
      last_full = nil
      found.each do |f|
        case f.kind
        when :case_full, :statute, :regulation
          last_full = f
        when :id_cite
          f.resolved_from = last_full
        when :case_short
          f.resolved_from = nearest_full(found, f) { |candidate|
            candidate.volume == f.volume && candidate.reporter == f.reporter
          } || nearest_full(found, f) { |candidate| name_matches?(candidate, f.case_name) }
        when :supra_cite
          f.resolved_from = nearest_full(found, f) { |candidate| name_matches?(candidate, f.case_name) }
        end
        f.normalized ||= f.resolved_from&.normalized
      end
    end

    def nearest_full(found, from)
      found.select { |f| f.full? && f.position < from.position }
           .reverse
           .find { |candidate| yield(candidate) }
    end

    def name_matches?(candidate, short_name)
      return false if candidate.case_name.blank? || short_name.blank?

      candidate.case_name.downcase.split(/[\s,]+/).include?(short_name.downcase.split.first)
    end
  end
end
