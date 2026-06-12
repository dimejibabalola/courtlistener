class Party < ApplicationRecord
  has_many :case_parties, dependent: :destroy
  has_many :documents, through: :case_parties

  validates :name, presence: true
end
