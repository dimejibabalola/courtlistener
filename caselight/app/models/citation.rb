class Citation < ApplicationRecord
  belongs_to :document

  enum :kind, { official: 0, parallel: 1, neutral: 2, statute: 3, regulation: 4 },
       default: :official

  validates :raw, presence: true
  validates :normalized, presence: true, uniqueness: true

  before_validation { self.normalized = self.class.normalize(raw) if raw.present? }

  # "987 F. 3d  1234" / "987 f3d 1234" / "987 F.3d 1234" all normalize the same.
  def self.normalize(raw)
    raw.to_s.downcase
       .gsub(/[§]/, "s")
       .gsub(/[.,()]/, "")
       .gsub(/\s+/, " ")
       .strip
  end

  def self.lookup(raw)
    find_by(normalized: normalize(raw))
  end
end
