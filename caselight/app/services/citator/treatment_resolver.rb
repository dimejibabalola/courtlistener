module Citator
  # Maps citing-reference treatments to the three citator signals and
  # resolves a document's denormalized flag as the *worst* inbound signal.
  #
  # CitingReference enum values are grouped by tens (0x positive/neutral,
  # 1x cautionary, 2x negative), so bucket comparisons are integer math.
  class TreatmentResolver
    CLASSIFICATIONS = %i[positive cautionary negative].freeze

    BADGES = {
      "untreated" => { label: "Unreviewed", color: "gray" },
      "positive" => { label: "Good Law", color: "green" },
      "cautionary" => { label: "Caution", color: "yellow" },
      "negative" => { label: "Negative", color: "red" }
    }.freeze

    class << self
      # Accepts a treatment name (symbol/string) or raw enum integer.
      def classify(treatment)
        value = treatment.is_a?(Integer) ? treatment : CitingReference.treatments.fetch(treatment.to_s)
        case value
        when 0...10 then :positive
        when 10...20 then :cautionary
        else :negative
        end
      end

      def severity(classification)
        CLASSIFICATIONS.index(classification.to_sym)&.+(1) || 0
      end

      # Worst-wins across a set of treatments.
      def worst(treatments)
        treatments.map { |t| classify(t) }.max_by { |c| severity(c) }
      end

      def badge_for(status)
        BADGES.fetch(status.to_s, BADGES["untreated"])
      end

      # Counts for the treatment panel: positive / distinguished / followed /
      # overruled buckets plus the total inbound count.
      def summary_counts(document)
        by_treatment = document.inbound_references.group(:treatment).count
        {
          positive: by_treatment.sum { |t, n| classify(t) == :positive ? n : 0 },
          cautionary: by_treatment.sum { |t, n| classify(t) == :cautionary ? n : 0 },
          negative: by_treatment.sum { |t, n| classify(t) == :negative ? n : 0 },
          distinguished: by_treatment.fetch("distinguished", 0),
          followed: by_treatment.fetch("followed", 0),
          overruled: by_treatment.fetch("overruled", 0),
          cited_by: by_treatment.values.sum
        }
      end
    end

    def initialize(document)
      @document = document
    end

    # Recompute and persist the denormalized flag. Returns the new status.
    def resolve!
      status = resolved_status
      if @document.treatment_status != status.to_s
        @document.update_columns(
          treatment_status: Document.treatment_statuses.fetch(status.to_s),
          updated_at: Time.current
        )
        @document.treatment_status = status.to_s
      end
      status
    end

    def resolved_status
      # Enum integers are bucket-ordered, so MAX() lands in the worst bucket.
      worst_value = @document.inbound_references.maximum(:treatment)
      return :untreated if worst_value.nil?

      self.class.classify(worst_value)
    end
  end
end
