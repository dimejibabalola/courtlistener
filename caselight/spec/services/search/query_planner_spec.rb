require "rails_helper"

RSpec.describe Search::QueryPlanner do
  def strategy(query) = described_class.plan(query).strategy

  describe "citation detection" do
    it "routes reporter citations to direct lookup" do
      expect(strategy("987 F.3d 1234")).to eq(:citation)
      expect(strategy("559 F.3d 220")).to eq(:citation)
      expect(strategy("202 Cal. App. 5th 321")).to eq(:citation)
      expect(strategy("812 S.E.2d 45")).to eq(:citation)
      expect(strategy("Anderson v. Summit Holdings, Inc., 987 F.3d 1234 (7th Cir. 2021)")).to eq(:citation)
    end

    it "routes statutes and regulations to direct lookup" do
      expect(strategy("28 U.S.C. § 1332")).to eq(:citation)
      expect(strategy("17 C.F.R. § 240.10b-5")).to eq(:citation)
    end

    it "does not treat prose mentioning numbers as a citation" do
      expect(strategy("damages of 987 dollars for 1234 widgets")).to eq(:natural)
    end
  end

  describe "terms-and-connectors detection" do
    it "detects uppercase boolean operators" do
      expect(strategy("fraud AND veil")).to eq(:boolean)
      expect(strategy("alter OR instrumentality")).to eq(:boolean)
      expect(strategy("veil NOT contract")).to eq(:boolean)
      expect(strategy("veil % contract")).to eq(:boolean)
    end

    it "ignores lowercase 'and'/'or' in prose" do
      expect(strategy("piercing the veil and shareholder liability")).to eq(:natural)
      expect(strategy("alter ego or instrumentality theory")).to eq(:natural)
    end

    it "detects proximity, root expander, wildcard, phrase and grouping" do
      expect(strategy("veil /5 pierc")).to eq(:boolean)
      expect(strategy("veil /s fraud")).to eq(:boolean)
      expect(strategy("veil /p fraud")).to eq(:boolean)
      expect(strategy("litigat! veil")).to eq(:boolean)
      expect(strategy("wom*n shareholder")).to eq(:boolean)
      expect(strategy(%("alter ego"))).to eq(:boolean)
      expect(strategy("fraud AND (alter! OR instrumentality)")).to eq(:boolean)
    end
  end

  describe "natural language" do
    it "routes prose questions to hybrid search" do
      expect(strategy("when can a court disregard the corporate entity?")).to eq(:natural)
      expect(strategy("piercing the corporate veil standard")).to eq(:natural)
    end

    it "handles blank queries" do
      expect(strategy("")).to eq(:natural)
      expect(strategy("   ")).to eq(:natural)
    end
  end

  it "records the reason for the routing decision" do
    expect(described_class.plan("987 F.3d 1234").reason).to match(/citation/)
    expect(described_class.plan("a AND b").reason).to match(/connectors/)
  end
end
