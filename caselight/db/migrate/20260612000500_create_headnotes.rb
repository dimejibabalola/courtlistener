class CreateHeadnotes < ActiveRecord::Migration[8.1]
  def change
    create_table :headnotes do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :number, null: false
      t.text :text, null: false
      t.column :embedding, :vector, limit: Rails.configuration.x.embedding_dimensions
      t.timestamps
    end
    add_index :headnotes, [:document_id, :number], unique: true
    add_index :headnotes, :embedding, using: :hnsw, opclass: :vector_cosine_ops

    create_table :headnote_topics do |t|
      t.references :headnote, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    add_index :headnote_topics, [:headnote_id, :topic_id], unique: true
  end
end
