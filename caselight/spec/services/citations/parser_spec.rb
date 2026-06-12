require "rails_helper"

RSpec.describe Citations::Parser do
  describe "full case citations" do
    it "parses volume / reporter / page with pin cite and year" do
      found = described_class.parse("Anderson v. Summit Holdings, Inc., 987 F.3d 1234, 1241 (7th Cir. 2021).")
      expect(found.size).to eq(1)
      cite = found.first
      expect(cite.kind).to eq(:case_full)
      expect(cite.volume).to eq(987)
      expect(cite.reporter).to eq("F.3d")
      expect(cite.page).to eq(1234)
      expect(cite.pin_cite).to eq("1241")
      expect(cite.court_year).to eq(2021)
      expect(cite.normalized).to eq("987 f3d 1234")
    end

    it "captures the case name preceding the citation" do
      found = described_class.parse("As held in Bird v. Phoenix Ventures, Inc., 812 S.E.2d 45 (N.C. Ct. App. 2019).")
      expect(found.first.case_name).to include("Bird v. Phoenix Ventures")
    end

    it "recognizes In re style names" do
      found = described_class.parse("See In re Fairfield Manufacturing Corp., 654 F.3d 789 (3d Cir. 2018).")
      expect(found.first.case_name).to match(/In re Fairfield/)
    end

    it "normalizes spacing variants of the reporter" do
      a = described_class.parse("987 F.3d 1234").first
      b = described_class.parse("987 F. 3d 1234").first
      expect(a.normalized).to eq(b.normalized)
    end
  end

  describe "statutes and regulations" do
    it "parses U.S.C. sections" do
      found = described_class.parse("Jurisdiction rests on 28 U.S.C. § 1332.")
      expect(found.size).to eq(1)
      expect(found.first.kind).to eq(:statute)
      expect(found.first.normalized).to eq("28 usc s 1332")
    end

    it "parses C.F.R. sections including letter subdivisions" do
      found = described_class.parse("See 17 C.F.R. § 240.10b-5.")
      expect(found.first.kind).to eq(:regulation)
      expect(found.first.raw).to include("240.10b-5")
    end
  end

  describe "short forms and resolution" do
    let(:text) do
      <<~T
        Anderson v. Summit Holdings, Inc., 987 F.3d 1234, 1241 (7th Cir. 2021), states the rule.
        Id. at 1242. Ownership alone is insufficient. Halvorsen v. Crown Pacific Partners,
        559 F.3d 220, 226 (7th Cir. 2009). Misuse is required. Anderson, 987 F.3d at 1244.
        The earlier case agrees. Halvorsen, supra, at 228.
      T
    end
    let(:found) { described_class.parse(text) }

    it "resolves id. to the immediately preceding authority" do
      id_cite = found.find { |f| f.kind == :id_cite }
      expect(id_cite.resolved_from.normalized).to eq("987 f3d 1234")
      expect(id_cite.pin_cite).to eq("1242")
      expect(id_cite.normalized).to eq("987 f3d 1234")
    end

    it "resolves '<Party>, vol Rep at pin' short cites by volume/reporter" do
      short = found.find { |f| f.kind == :case_short }
      expect(short.case_name).to eq("Anderson")
      expect(short.resolved_from.normalized).to eq("987 f3d 1234")
      expect(short.pin_cite).to eq("1244")
    end

    it "resolves supra by party name back to the first full cite" do
      supra = found.find { |f| f.kind == :supra_cite }
      expect(supra.case_name).to eq("Halvorsen")
      expect(supra.resolved_from.normalized).to eq("559 f3d 220")
      expect(supra.pin_cite).to eq("228")
    end

    it "keeps matches in document order" do
      expect(found.map(&:position)).to eq(found.map(&:position).sort)
    end
  end

  describe "overlap handling" do
    it "prefers the full cite over a short form occupying the same span" do
      found = described_class.parse("Anderson, 987 F.3d 1234, 1241 (7th Cir. 2021).")
      expect(found.count { |f| f.kind == :case_full }).to eq(1)
      expect(found.count { |f| f.kind == :case_short }).to eq(0)
    end
  end

  describe ".citation_query?" do
    it "accepts bare citations and citation-dominant strings" do
      expect(described_class.citation_query?("987 F.3d 1234")).to be(true)
      expect(described_class.citation_query?("28 U.S.C. § 1332")).to be(true)
    end

    it "rejects prose" do
      expect(described_class.citation_query?("when can a court pierce the corporate veil")).to be(false)
      expect(described_class.citation_query?("")).to be(false)
    end
  end
end
