class HeadnoteTopic < ApplicationRecord
  belongs_to :headnote
  belongs_to :topic, counter_cache: :headnotes_count

  validates :headnote_id, uniqueness: { scope: :topic_id }
end
