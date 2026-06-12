class CaseAttorney < ApplicationRecord
  belongs_to :document
  belongs_to :attorney

  enum :representing, { plaintiff: 0, defendant: 1, appellant: 2, appellee: 3, other: 4 },
       default: :other

  validates :attorney_id, uniqueness: { scope: :document_id }
end
