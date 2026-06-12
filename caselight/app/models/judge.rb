class Judge < ApplicationRecord
  include Sluggable

  belongs_to :court, optional: true
  has_many :case_judges, dependent: :destroy
  has_many :documents, through: :case_judges
  has_many :authored_documents, class_name: "Document", foreign_key: :author_judge_id,
           dependent: :nullify, inverse_of: :author_judge

  validates :name, presence: true
end
