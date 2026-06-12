class Attorney < ApplicationRecord
  has_many :case_attorneys, dependent: :destroy
  has_many :documents, through: :case_attorneys

  validates :name, presence: true
end
