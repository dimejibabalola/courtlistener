module Search
  # Fuses several ranked id lists into one. Standard RRF:
  #   score(d) = sum over lists of 1 / (k + rank(d))
  class ReciprocalRankFusion
    K = 60

    def self.fuse(*ranked_lists, k: K)
      scores = Hash.new(0.0)
      ranked_lists.each do |list|
        list.each_with_index do |id, index|
          scores[id] += 1.0 / (k + index + 1)
        end
      end
      scores.sort_by { |id, score| [-score, id] }.map(&:first)
    end
  end
end
