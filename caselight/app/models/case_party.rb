class CaseParty < ApplicationRecord
  belongs_to :document
  belongs_to :party

  enum :role, { plaintiff: 0, defendant: 1, appellant: 2, appellee: 3, petitioner: 4, respondent: 5 },
       default: :plaintiff

  validates :party_id, uniqueness: { scope: :document_id }
end
