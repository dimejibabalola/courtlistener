module ApplicationHelper
  # Treatment pill ("Good Law" / "Caution" / "Negative" / "Unreviewed").
  def treatment_badge(status_or_document, size: :sm)
    status = status_or_document.is_a?(Document) ? status_or_document.treatment_status : status_or_document.to_s
    badge = Citator::TreatmentResolver.badge_for(status)
    css = { "green" => "badge-green", "yellow" => "badge-yellow", "red" => "badge-red" }.fetch(badge[:color], "badge-gray")
    css += " px-2 py-1 text-xs" if size == :md
    tag.span(badge[:label], class: css)
  end

  def classification_dot(classification)
    color = { positive: "bg-green-500", cautionary: "bg-amber-400", negative: "bg-red-500" }
            .fetch(classification.to_sym, "bg-gray-300")
    tag.span("", class: "inline-block h-2 w-2 rounded-full #{color}", aria: { hidden: true })
  end

  # Search snippets arrive with <mark> tags from ts_headline/OpenSearch.
  def highlight_snippet(snippet)
    sanitize(snippet.to_s, tags: %w[mark b em], attributes: [])
  end

  def nav_item(label, path, icon_name, active:)
    link_to path,
            class: class_names("sidebar-link", "sidebar-link-active" => active),
            aria: { current: active ? "page" : nil }, title: label do
      icon(icon_name, class: "h-5 w-5 shrink-0") +
        tag.span(label, class: "truncate", data: { sidebar_target: "label" })
    end
  end

  def section_active?(*paths)
    paths.any? { |p| request.path == p || request.path.start_with?("#{p}/") }
  end

  def number_compact(n)
    number_with_delimiter(n)
  end

  def docket_display(document)
    document.docket_number.present? ? "Docket No. #{document.docket_number}" : nil
  end

  def date_display(date)
    date&.strftime("%b %-d, %Y")
  end

  # Research URLs that preserve the current query/filters while overriding
  # e.g. the selected document, tab, page or a facet.
  def research_url_with(**overrides)
    keep = request.query_parameters.slice("q", "scope", "sort", "page", "doc", "tab", "view", *Search::Filters::KEYS)
    research_path(keep.merge(overrides.stringify_keys).compact_blank)
  end

  def full_citation_line(document)
    parts = ["#{document.title}, #{document.display_citation}"]
    paren = [document.court&.abbreviation, document.decided_on&.year].compact.join(" ")
    parts << "(#{paren})" if paren.present?
    parts.join(" ")
  end
end
