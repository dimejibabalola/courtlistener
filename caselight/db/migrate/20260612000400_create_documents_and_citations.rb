class CreateDocumentsAndCitations < ActiveRecord::Migration[8.1]
  def up
    create_table :judges do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.references :court, foreign_key: true
      t.timestamps
    end

    create_table :documents do |t|
      t.string :type, null: false # STI: Case / Statute / Regulation / SecondarySource
      t.string :title, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :primary_citation
      t.references :jurisdiction, foreign_key: true
      t.references :court, foreign_key: true
      t.date :decided_on   # decision date (cases) or enactment date (statutes/regulations)
      t.date :argued_on
      t.string :docket_number
      t.text :full_text
      t.text :summary      # neutral summary shown on the Overview tab
      t.text :issue
      t.text :holding
      t.jsonb :key_facts, null: false, default: []
      t.string :disposition
      t.string :practice_area
      t.string :source_url
      t.string :source_name
      t.references :primary_topic, foreign_key: { to_table: :topics } # "Key Issue"
      t.references :author_judge, foreign_key: { to_table: :judges }
      t.string :panel_text # "Posner, Easterbrook, and Hamilton, Circuit Judges."
      t.references :lower_court, foreign_key: { to_table: :courts }
      t.string :lower_court_docket

      # Denormalized treatment signal (worst inbound CitingReference), kept
      # current by Citator::RecomputeTreatmentJob.
      t.integer :treatment_status, null: false, default: 0
      t.integer :cited_by_count, null: false, default: 0
      t.integer :cites_count, null: false, default: 0
      t.integer :headnotes_count, null: false, default: 0

      t.column :search_vector, :tsvector
      t.timestamps
    end
    add_index :documents, :type
    add_index :documents, :decided_on
    add_index :documents, :treatment_status
    add_index :documents, :practice_area
    add_index :documents, :docket_number
    add_index :documents, :cited_by_count
    add_index :documents, :search_vector, using: :gin
    add_index :documents, :title, using: :gin, opclass: :gin_trgm_ops, name: "index_documents_on_title_trgm"

    execute <<~SQL
      CREATE FUNCTION documents_search_vector_refresh() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
          setweight(to_tsvector('simple',  coalesce(NEW.primary_citation, '')), 'A') ||
          setweight(to_tsvector('simple',  coalesce(NEW.docket_number, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(NEW.summary, '')), 'B') ||
          setweight(to_tsvector('english', coalesce(NEW.holding, '')), 'B') ||
          setweight(to_tsvector('english', left(coalesce(NEW.full_text, ''), 800000)), 'C');
        RETURN NEW;
      END $$ LANGUAGE plpgsql;

      CREATE TRIGGER documents_search_vector_trigger
        BEFORE INSERT OR UPDATE OF title, primary_citation, docket_number, summary, holding, full_text
        ON documents FOR EACH ROW
        EXECUTE FUNCTION documents_search_vector_refresh();
    SQL

    # A document carries many parallel/alternate citations.
    create_table :citations do |t|
      t.references :document, null: false, foreign_key: true
      t.string :raw, null: false        # "987 F.3d 1234"
      t.string :normalized, null: false # "987 f3d 1234"
      t.integer :volume
      t.string :reporter
      t.integer :page
      t.integer :kind, null: false, default: 0 # official/parallel/neutral/statute/regulation
      t.timestamps
    end
    add_index :citations, :normalized, unique: true
    add_index :citations, [:reporter, :volume, :page]

    create_table :case_judges do |t|
      t.references :document, null: false, foreign_key: true
      t.references :judge, null: false, foreign_key: true
      t.integer :role, null: false, default: 0 # author/panel/concurring/dissenting
      t.timestamps
    end
    add_index :case_judges, [:document_id, :judge_id], unique: true

    create_table :attorneys do |t|
      t.string :name, null: false
      t.string :firm_name
      t.timestamps
    end

    create_table :case_attorneys do |t|
      t.references :document, null: false, foreign_key: true
      t.references :attorney, null: false, foreign_key: true
      t.integer :representing, null: false, default: 0
      t.timestamps
    end
    add_index :case_attorneys, [:document_id, :attorney_id], unique: true

    create_table :parties do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :case_parties do |t|
      t.references :document, null: false, foreign_key: true
      t.references :party, null: false, foreign_key: true
      t.integer :role, null: false, default: 0 # plaintiff/defendant/appellant/appellee/petitioner/respondent
      t.timestamps
    end
    add_index :case_parties, [:document_id, :party_id], unique: true
  end

  def down
    drop_table :case_parties
    drop_table :parties
    drop_table :case_attorneys
    drop_table :attorneys
    drop_table :case_judges
    drop_table :citations
    execute "DROP TRIGGER IF EXISTS documents_search_vector_trigger ON documents"
    execute "DROP FUNCTION IF EXISTS documents_search_vector_refresh()"
    drop_table :documents
    drop_table :judges
  end
end
