class CreateUploadsAndBriefs < ActiveRecord::Migration[8.1]
  def up
    create_table :uploaded_documents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :matter, foreign_key: true
      t.string :title, null: false
      t.integer :kind, null: false, default: 0 # brief/opinion/contract/correspondence/other
      t.integer :status, null: false, default: 0 # pending/processing/ready/failed
      t.string :ocr_method
      t.text :extracted_text
      t.integer :pages_count
      t.string :error_message
      t.datetime :archived_at
      t.datetime :trashed_at
      t.column :search_vector, :tsvector
      t.timestamps
    end
    add_index :uploaded_documents, :search_vector, using: :gin

    execute <<~SQL
      CREATE FUNCTION uploaded_documents_search_vector_refresh() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
          setweight(to_tsvector('english', left(coalesce(NEW.extracted_text, ''), 800000)), 'C');
        RETURN NEW;
      END $$ LANGUAGE plpgsql;

      CREATE TRIGGER uploaded_documents_search_vector_trigger
        BEFORE INSERT OR UPDATE OF title, extracted_text
        ON uploaded_documents FOR EACH ROW
        EXECUTE FUNCTION uploaded_documents_search_vector_refresh();
    SQL

    create_table :brief_analyses do |t|
      t.references :uploaded_document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0 # pending/processing/complete/failed
      t.integer :authorities_count, null: false, default: 0
      t.integer :clean_count, null: false, default: 0
      t.integer :cautionary_count, null: false, default: 0
      t.integer :negative_count, null: false, default: 0
      t.integer :unmatched_count, null: false, default: 0
      t.string :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    create_table :brief_citations do |t|
      t.references :brief_analysis, null: false, foreign_key: true
      t.references :document, foreign_key: true # matched authority, if any
      t.references :resolved_from, foreign_key: { to_table: :brief_citations }
      t.integer :position, null: false, default: 0
      t.string :raw_cite, null: false
      t.string :normalized_cite
      t.integer :kind, null: false, default: 0 # case_full/case_short/id_cite/supra_cite/statute/regulation/unknown
      t.string :pin_cite
      t.text :context # surrounding text from the brief
      t.integer :status, null: false, default: 0 # matched/unmatched/needs_review
      t.integer :treatment_status, null: false, default: 0 # snapshot at analysis time
      t.timestamps
    end
    add_index :brief_citations, [:brief_analysis_id, :position]
  end

  def down
    drop_table :brief_citations
    drop_table :brief_analyses
    execute "DROP TRIGGER IF EXISTS uploaded_documents_search_vector_trigger ON uploaded_documents"
    execute "DROP FUNCTION IF EXISTS uploaded_documents_search_vector_refresh()"
    drop_table :uploaded_documents
  end
end
