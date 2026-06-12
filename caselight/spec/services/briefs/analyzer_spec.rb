require "rails_helper"

RSpec.describe Briefs::Analyzer do
  let(:user) { create(:user) }

  let!(:anderson) do
    create(:case_document, title: "Anderson v. Summit Holdings, Inc.", primary_citation: "987 F.3d 1234")
  end
  let!(:crane) do
    create(:case_document, title: "Crane v. Vortex Industries, Inc.", primary_citation: "88 N.E.3d 410")
  end

  before do
    create(:citing_reference, cited_document: anderson, treatment: :followed)
    create(:citing_reference, cited_document: crane, treatment: :overruled)
    [anderson, crane].each { |d| Citator::TreatmentResolver.new(d).resolve! }
  end

  let(:brief_text) do
    <<~BRIEF
      The veil may be pierced. Anderson v. Summit Holdings, Inc., 987 F.3d 1234, 1241 (7th Cir. 2021).
      Id. at 1242. Undercapitalization alone suffices. Crane v. Vortex Industries, Inc., 88 N.E.3d 410, 415 (2008).
      See also Nobody v. Nothing Corp., 777 P.3d 888 (2029). Jurisdiction: 28 U.S.C. § 1332.
    BRIEF
  end

  let(:upload) { create(:uploaded_document, user:, extracted_text: brief_text) }
  let(:analysis) { create(:brief_analysis, uploaded_document: upload, user:) }

  it "extracts, matches, snapshots treatment and counts statuses" do
    described_class.new(analysis).run!
    analysis.reload

    expect(analysis).to be_complete
    rows = analysis.brief_citations.index_by(&:raw_cite)

    anderson_row = analysis.brief_citations.find { |c| c.raw_cite.include?("987 F.3d 1234") && c.case_full? }
    expect(anderson_row.document).to eq(anderson)
    expect(anderson_row).to be_matched
    expect(anderson_row.authority_status).to eq("clean")

    id_row = analysis.brief_citations.find(&:id_cite?)
    expect(id_row.document).to eq(anderson)
    expect(id_row.resolved_from).to eq(anderson_row)

    crane_row = analysis.brief_citations.find { |c| c.raw_cite.include?("88 N.E.3d 410") }
    expect(crane_row.treatment_status).to eq("negative")
    expect(crane_row.authority_status).to eq("negative")

    unknown = analysis.brief_citations.find { |c| c.raw_cite.include?("777 P.3d 888") }
    expect(unknown.document).to be_nil
    expect(unknown.authority_status).to eq("unmatched")

    expect(analysis.authorities_count).to eq(analysis.brief_citations.count)
    expect(analysis.negative_count).to eq(1)
    expect(analysis.unmatched_count).to be >= 1
    expect(rows.keys.join).to include("28 U.S.C.")
  end

  it "keeps pin-cite context from the brief" do
    described_class.new(analysis).run!
    row = analysis.brief_citations.find { |c| c.raw_cite.include?("987 F.3d 1234") && c.case_full? }
    expect(row.context).to include("veil may be pierced")
    expect(row.pin_cite).to eq("1241")
  end

  it "marks the analysis failed when there is no text" do
    empty_upload = create(:uploaded_document, user:, extracted_text: nil)
    empty_analysis = create(:brief_analysis, uploaded_document: empty_upload, user:)
    expect { described_class.new(empty_analysis).run! }.to raise_error(StandardError)
    expect(empty_analysis.reload).to be_failed
  end

  it "exports a table of authorities as CSV" do
    described_class.new(analysis).run!
    csv = Briefs::ToaExporter.new(analysis).to_csv
    expect(csv).to include("Authority,Citation")
    expect(csv).to include("Anderson v. Summit Holdings")
  end
end
