module Search
  # Normalizes facet/filter params and applies them to a Document scope.
  class Filters
    KEYS = %w[
      scope jurisdiction_id court_level doc_type date_from date_to
      practice_area topic_id judge_id treatment
    ].freeze

    def self.normalize(params)
      raw = params.respond_to?(:permit) ? params.permit(*KEYS).to_h : params.to_h
      raw.stringify_keys.slice(*KEYS).reject { |_, v| v.blank? || v == "all" }
    end

    def self.active?(filters)
      normalize(filters).any?
    end

    def self.apply(scope, filters)
      f = normalize(filters)
      scope = scope.joins(:jurisdiction).where(jurisdictions: { kind: f["scope"] }) if f["scope"].in?(%w[federal state])
      scope = scope.where(jurisdiction_id: f["jurisdiction_id"]) if f["jurisdiction_id"]
      scope = scope.joins(:court).where(courts: { level: f["court_level"] }) if f["court_level"]
      scope = scope.where(type: f["doc_type"]) if f["doc_type"]
      scope = scope.where(practice_area: f["practice_area"]) if f["practice_area"]
      scope = scope.where(primary_topic_id: f["topic_id"]) if f["topic_id"]
      scope = scope.where(author_judge_id: f["judge_id"]) if f["judge_id"]
      scope = scope.where(treatment_status: f["treatment"]) if f["treatment"]
      scope = scope.where(decided_on: Date.parse(f["date_from"])..) if safe_date(f["date_from"])
      scope = scope.where(decided_on: ..Date.parse(f["date_to"])) if safe_date(f["date_to"])
      scope
    end

    def self.safe_date(value)
      value.present? && (Date.parse(value) rescue nil)
    end
  end
end
