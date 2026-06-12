require "rails_helper"

RSpec.describe Search::BooleanTranslator do
  describe ".to_tsquery" do
    it "translates AND / OR / NOT" do
      expect(described_class.to_tsquery("fraud AND veil")).to eq("fraud & veil")
      expect(described_class.to_tsquery("fraud OR veil")).to eq("fraud | veil")
      expect(described_class.to_tsquery("fraud NOT contract")).to eq("fraud & ! contract")
      expect(described_class.to_tsquery("fraud % contract")).to eq("fraud & ! contract")
    end

    it "supports grouping" do
      expect(described_class.to_tsquery("fraud AND (alter OR instrumentality)"))
        .to eq("fraud & ( alter | instrumentality )")
    end

    it "translates the root expander and wildcards to prefix matches" do
      expect(described_class.to_tsquery("litigat!")).to eq("litigat:*")
      expect(described_class.to_tsquery("pierc* veil")).to eq("pierc:* & veil")
    end

    it "translates quoted phrases to adjacency" do
      expect(described_class.to_tsquery(%("alter ego"))).to eq("(alter <-> ego)")
    end

    it "ANDs adjacent bare terms (implicit operator)" do
      expect(described_class.to_tsquery("fraud veil")).to eq("fraud & veil")
    end

    it "degrades proximity connectors to AND" do
      expect(described_class.to_tsquery("veil /5 pierce")).to eq("veil & pierce")
      expect(described_class.to_tsquery("veil /p fraud")).to eq("veil & fraud")
    end

    it "produces valid tsquery for the kitchen sink" do
      translated = described_class.to_tsquery(%[fraud AND (alter! OR instrumentality) NOT contract])
      expect(translated).to eq("fraud & ( alter:* | instrumentality ) & ! contract")
      # Postgres should accept it.
      expect {
        ActiveRecord::Base.connection.select_value(
          "SELECT to_tsquery('english', #{ActiveRecord::Base.connection.quote(translated)})"
        )
      }.not_to raise_error
    end
  end

  describe ".to_query_string" do
    it "keeps boolean operators in OpenSearch syntax" do
      expect(described_class.to_query_string("fraud AND veil NOT contract"))
        .to eq("fraud AND veil NOT contract")
    end

    it "converts proximity to phrase-with-slop" do
      expect(described_class.to_query_string("veil /5 pierc!")).to eq(%("veil pierc"~5))
      expect(described_class.to_query_string("veil /s fraud")).to eq(%("veil fraud"~12))
    end

    it "converts the root expander to a wildcard" do
      expect(described_class.to_query_string("litigat!")).to eq("litigat*")
    end

    it "preserves phrases and implicit ANDs terms" do
      expect(described_class.to_query_string(%["alter ego" commingling])).to eq(%["alter ego" AND commingling])
    end
  end
end
