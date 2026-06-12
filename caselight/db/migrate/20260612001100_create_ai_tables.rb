class CreateAiTables < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :context, polymorphic: true # Document or Matter the chat is anchored to
      t.string :title
      t.string :provider
      t.string :model
      t.timestamps
    end

    create_table :ai_messages do |t|
      t.references :ai_conversation, null: false, foreign_key: true
      t.integer :role, null: false, default: 0 # user / assistant
      t.text :content, null: false
      t.jsonb :sources, null: false, default: [] # grounding passages [{document_id:, citation:, quote:}]
      t.string :provider
      t.string :model
      t.timestamps
    end
  end
end
