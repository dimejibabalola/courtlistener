require "rails_helper"

RSpec.describe Citator::TreatmentResolver do
  describe ".classify" do
    it "buckets every treatment into positive / cautionary / negative" do
      expect(described_class.classify(:cited)).to eq(:positive)
      expect(described_class.classify(:cited_favorably)).to eq(:positive)
      expect(described_class.classify(:followed)).to eq(:positive)
      expect(described_class.classify(:affirmed)).to eq(:positive)
      expect(described_class.classify(:explained)).to eq(:positive)

      expect(described_class.classify(:distinguished)).to eq(:cautionary)
      expect(described_class.classify(:limited)).to eq(:cautionary)
      expect(described_class.classify(:criticized)).to eq(:cautionary)
      expect(described_class.classify(:questioned)).to eq(:cautionary)
      expect(described_class.classify(:called_into_doubt)).to eq(:cautionary)

      expect(described_class.classify(:overruled)).to eq(:negative)
      expect(described_class.classify(:reversed)).to eq(:negative)
      expect(described_class.classify(:vacated)).to eq(:negative)
      expect(described_class.classify(:abrogated)).to eq(:negative)
      expect(described_class.classify(:superseded)).to eq(:negative)
    end

    it "accepts raw enum integers" do
      expect(described_class.classify(CitingReference.treatments[:overruled])).to eq(:negative)
    end
  end

  describe ".worst" do
    it "is worst-wins across mixed treatments" do
      expect(described_class.worst([:followed, :distinguished])).to eq(:cautionary)
      expect(described_class.worst([:followed, :distinguished, :overruled])).to eq(:negative)
      expect(described_class.worst([:cited, :followed])).to eq(:positive)
    end
  end

  describe "#resolve!" do
    let(:authority) { create(:case_document) }

    it "marks documents with no inbound references as untreated" do
      expect(described_class.new(authority).resolve!).to eq(:untreated)
      expect(authority.reload.treatment_status).to eq("untreated")
    end

    it "marks purely positive treatment as positive" do
      create(:citing_reference, cited_document: authority, treatment: :followed)
      create(:citing_reference, cited_document: authority, treatment: :cited)
      expect(described_class.new(authority).resolve!).to eq(:positive)
      expect(authority.reload.treatment_status).to eq("positive")
    end

    it "lets a single cautionary citation downgrade a sea of positives" do
      5.times { create(:citing_reference, cited_document: authority, treatment: :followed) }
      create(:citing_reference, cited_document: authority, treatment: :distinguished)
      expect(described_class.new(authority).resolve!).to eq(:cautionary)
    end

    it "lets negative treatment dominate everything" do
      create(:citing_reference, cited_document: authority, treatment: :followed)
      create(:citing_reference, cited_document: authority, treatment: :distinguished)
      create(:citing_reference, cited_document: authority, treatment: :overruled)
      expect(described_class.new(authority).resolve!).to eq(:negative)
      expect(authority.reload).to be_negative
    end

    it "recomputes downward when the worst edge is removed" do
      create(:citing_reference, cited_document: authority, treatment: :followed)
      bad = create(:citing_reference, cited_document: authority, treatment: :reversed)
      described_class.new(authority).resolve!
      expect(authority.reload.treatment_status).to eq("negative")

      bad.destroy!
      described_class.new(authority.reload).resolve!
      expect(authority.reload.treatment_status).to eq("positive")
    end
  end

  describe "counter maintenance via CitingReference" do
    it "keeps cited_by/cites counts in sync on create and destroy" do
      citing = create(:case_document)
      cited = create(:case_document)
      ref = create(:citing_reference, citing_document: citing, cited_document: cited)
      expect(cited.reload.cited_by_count).to eq(1)
      expect(citing.reload.cites_count).to eq(1)

      ref.destroy!
      expect(cited.reload.cited_by_count).to eq(0)
      expect(citing.reload.cites_count).to eq(0)
    end

    it "rejects self-citation" do
      doc = create(:case_document)
      ref = build(:citing_reference, citing_document: doc, cited_document: doc)
      expect(ref).not_to be_valid
    end
  end

  describe ".summary_counts" do
    it "produces the treatment panel numbers" do
      authority = create(:case_document)
      2.times { create(:citing_reference, cited_document: authority, treatment: :followed) }
      create(:citing_reference, cited_document: authority, treatment: :distinguished)
      create(:citing_reference, cited_document: authority, treatment: :cited_favorably)

      counts = described_class.summary_counts(authority)
      expect(counts[:followed]).to eq(2)
      expect(counts[:distinguished]).to eq(1)
      expect(counts[:positive]).to eq(3)
      expect(counts[:cautionary]).to eq(1)
      expect(counts[:overruled]).to eq(0)
      expect(counts[:cited_by]).to eq(4)
    end
  end

  describe ".badge_for" do
    it "maps statuses to the UI badges" do
      expect(described_class.badge_for(:positive)[:label]).to eq("Good Law")
      expect(described_class.badge_for(:cautionary)[:label]).to eq("Caution")
      expect(described_class.badge_for(:negative)[:label]).to eq("Negative")
      expect(described_class.badge_for(:untreated)[:label]).to eq("Unreviewed")
    end
  end
end
