require "rails_helper"

RSpec.describe Search::Engine do
  before { ENV["DISABLE_OPENSEARCH"] = "1" }
  after { ENV.delete("DISABLE_OPENSEARCH") }

  let!(:veil_case) do
    create(:case_document, :indexed,
           title: "Keller v. Brockton Holdings, Inc.",
           primary_citation: "120 F.4th 300",
           summary: "Piercing the corporate veil requires misuse of the entity.",
           full_text: "The corporate veil may be pierced where the shareholder misuses the entity to work a fraud or injustice. Undercapitalization and commingling support piercing the corporate veil.")
  end
  let!(:contract_case) do
    create(:case_document, :indexed,
           title: "Nash v. Quill Logistics Corp.",
           primary_citation: "121 F.4th 410",
           summary: "Contract formation requires offer and acceptance.",
           full_text: "A contract requires offer, acceptance and consideration. Nothing about corporations here.")
  end

  it "routes citations to a direct fetch" do
    results = described_class.new.call(q: "120 F.4th 300")
    expect(results.query_type).to eq("citation")
    expect(results.total).to eq(1)
    expect(results.entries.first.document).to eq(veil_case)
  end

  it "answers boolean queries through the Postgres fallback" do
    results = described_class.new.call(q: "veil AND undercapital!")
    expect(results.query_type).to eq("boolean")
    expect(results.entries.map(&:document)).to include(veil_case)
    expect(results.entries.map(&:document)).not_to include(contract_case)
    expect(results.engines).to eq(["postgres"])
  end

  it "blends lexical and vector results for natural language" do
    results = described_class.new.call(q: "piercing the corporate veil")
    expect(results.query_type).to eq("natural")
    expect(results.entries.map(&:document)).to include(veil_case)
    expect(results.entries.first.document).to eq(veil_case)
    expect(results.engines).to include("postgres")
    expect(results.engines).to include("pgvector")
  end

  it "provides highlighted snippets" do
    results = described_class.new.call(q: "corporate veil misuse")
    entry = results.entries.find { |e| e.document == veil_case }
    expect(entry.snippet).to include("<mark>")
  end

  it "applies filters" do
    other_court = create(:court)
    scoped = described_class.new.call(q: "corporate veil", filters: { "court_level" => "trial" })
    expect(scoped.entries).to be_empty

    unscoped = described_class.new.call(q: "corporate veil", filters: { "court_level" => "appellate" })
    expect(unscoped.entries.map(&:document)).to include(veil_case)
  end

  it "builds facet counts from the result set" do
    results = described_class.new.call(q: "corporate veil")
    expect(results.facets.doc_types.map(&:value)).to include("Case")
  end

  it "falls back to natural search when a citation has no match" do
    results = described_class.new.call(q: "999 F.4th 999")
    expect(results.query_type).to eq("citation")
    expect(results.reason).to match(/no exact citation match/)
  end
end
