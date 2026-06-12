class Annotation < ApplicationRecord
  belongs_to :user
  belongs_to :document

  enum :kind, { note: 0, highlight: 1 }, default: :note

  validates :body, presence: true, if: :note?
  validates :quote, presence: true, if: :highlight?
end
