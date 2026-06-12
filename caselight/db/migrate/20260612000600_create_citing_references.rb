class CreateCitingReferences < ActiveRecord::Migration[8.1]
  def change
    # Directed edge citing_document -> cited_document. The spine of treatment
    # flags and the citation graph.
    create_table :citing_references do |t|
      t.references :citing_document, null: false, foreign_key: { to_table: :documents }
      t.references :cited_document, null: false, foreign_key: { to_table: :documents }
      t.integer :treatment, null: false, default: 0
      t.integer :depth, null: false, default: 1 # 1 passing mention .. 4 extended analysis
      t.string :pin_cite
      t.text :passage # the pin-cited passage in the citing opinion
      t.timestamps
    end
    add_index :citing_references, [:citing_document_id, :cited_document_id],
              unique: true, name: "index_citing_references_on_edge"
    add_index :citing_references, [:cited_document_id, :treatment],
              name: "index_citing_references_on_cited_and_treatment"
  end
end
