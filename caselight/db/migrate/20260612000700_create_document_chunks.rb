class CreateDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    # Passage-level embeddings for semantic search and source-grounded answers.
    create_table :document_chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text :content, null: false
      t.column :embedding, :vector, limit: Rails.configuration.x.embedding_dimensions
      t.timestamps
    end
    add_index :document_chunks, [:document_id, :position], unique: true
    add_index :document_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
