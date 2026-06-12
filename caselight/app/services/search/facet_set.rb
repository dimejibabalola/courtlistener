module Search
  # Resolves raw facet count hashes ({ id => count }) into labeled values
  # ready for rendering, regardless of which engine produced them.
  class FacetSet
    Value = Struct.new(:value, :label, :count, keyword_init: true)

    DIMENSIONS = %i[jurisdictions court_levels doc_types practice_areas topics judges treatments].freeze

    def self.build(raw)
      new(raw || {})
    end

    def initialize(raw)
      @raw = raw.symbolize_keys
    end

    DIMENSIONS.each do |dimension|
      define_method(dimension) { values_for(dimension) }
    end

    def any? = DIMENSIONS.any? { |d| values_for(d).any? }

    private

    def values_for(dimension)
      @resolved ||= {}
      @resolved[dimension] ||= begin
        counts = @raw.fetch(dimension, {})
        labels = labels_for(dimension, counts.keys)
        counts.filter_map do |key, count|
          label = labels[key.to_s]
          next if label.nil?

          Value.new(value: key.to_s, label:, count:)
        end.sort_by { |v| -v.count }
      end
    end

    def labels_for(dimension, keys)
      case dimension
      when :jurisdictions
        Jurisdiction.where(id: keys).pluck(:id, :name).to_h { |id, name| [id.to_s, name] }
      when :topics
        Topic.where(id: keys).pluck(:id, :name).to_h { |id, name| [id.to_s, name] }
      when :judges
        Judge.where(id: keys).pluck(:id, :name).to_h { |id, name| [id.to_s, name] }
      when :court_levels
        keys.to_h { |k| [k.to_s, level_label(k)] }
      when :doc_types
        keys.to_h { |k| [k.to_s, k.to_s == "SecondarySource" ? "Secondary Source" : k.to_s] }
      when :treatments
        keys.to_h { |k| [k.to_s, Citator::TreatmentResolver.badge_for(k)[:label]] }
      else
        keys.to_h { |k| [k.to_s, k.to_s] }
      end
    end

    def level_label(key)
      value = key.is_a?(Integer) ? Court.levels.key(key) : key.to_s
      value&.titleize
    end
  end
end
