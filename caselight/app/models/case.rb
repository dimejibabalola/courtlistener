class Case < Document
  validates :court, presence: true

  def self.model_name
    @_model_name ||= ActiveModel::Name.new(self, nil, "Case")
  end
end
