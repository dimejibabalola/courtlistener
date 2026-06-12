class CaseJudge < ApplicationRecord
  belongs_to :document
  belongs_to :judge

  enum :role, { panel: 0, author: 1, concurring: 2, dissenting: 3 }, default: :panel

  validates :judge_id, uniqueness: { scope: :document_id }
end
