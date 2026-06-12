require "rails_helper"

RSpec.describe Citations::Matcher do
  let!(:anderson) do
    create(:case_document, title: "Anderson v. Summit Holdings, Inc.", primary_citation: "987 F.3d 1234")
  end

  it "matches an exact normalized citation" do
    found = Citations::Parser.parse("See Anderson v. Summit Holdings, Inc., 987 F.3d 1234 (7th Cir. 2021).").first
    result = described_class.match(found)
    expect(result.status).to eq(:matched)
    expect(result.document).to eq(anderson)
    expect(result.confidence).to eq(1.0)
  end

  it "matches spacing/punctuation variants" do
    found = Citations::Parser.parse("987 F. 3d 1234").first
    expect(described_class.match(found).document).to eq(anderson)
  end

  it "matches a resolved short form through its antecedent" do
    text = "Anderson v. Summit Holdings, Inc., 987 F.3d 1234 (7th Cir. 2021). Id. at 1242."
    id_cite = Citations::Parser.parse(text).find { |f| f.kind == :id_cite }
    expect(described_class.match(id_cite).document).to eq(anderson)
  end

  it "falls back to fuzzy title matching for review" do
    found = Citations::Parser.parse("Anderson v. Summit Holdings Inc., 999 F.4th 555 (7th Cir. 2024).").first
    result = described_class.match(found)
    expect(result.status).to eq(:needs_review)
    expect(result.document).to eq(anderson)
    expect(result.confidence).to be > 0.45
  end

  it "returns unmatched when nothing fits" do
    found = Citations::Parser.parse("Zzyzx v. Qwerty Corp., 444 P.3d 9999 (2030).").first
    result = described_class.match(found)
    expect(result.status).to eq(:unmatched)
    expect(result.document).to be_nil
  end
end
