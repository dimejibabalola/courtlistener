require "rails_helper"

RSpec.describe Embeddings::ServiceEmbedder do
  subject(:embedder) { described_class.new }

  # Captures the request body so we can assert on the query/document mode, and
  # returns a fake response with the given status/body.
  def stub_service(status:, body:)
    response = double("response", code: status.to_s, body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(status == 200)

    http = instance_double(Net::HTTP)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:request) do |request|
      @captured_body = JSON.parse(request.body)
      response
    end
  end

  it "encodes documents in document mode and returns the vectors" do
    vector = Array.new(Embeddings.dimensions, 0.1)
    stub_service(status: 200, body: { embeddings: [vector], dim: Embeddings.dimensions }.to_json)

    result = embedder.embed_batch(["some opinion text"])

    expect(@captured_body).to include("mode" => "document", "texts" => ["some opinion text"])
    expect(result).to eq([vector])
  end

  it "encodes a search query in query mode" do
    vector = Array.new(Embeddings.dimensions, 0.2)
    stub_service(status: 200, body: { embeddings: [vector], dim: Embeddings.dimensions }.to_json)

    result = embedder.embed("piercing the corporate veil")

    expect(@captured_body["mode"]).to eq("query")
    expect(result).to eq(vector)
  end

  it "fails soft (nil) on a query when the service errors" do
    stub_service(status: 500, body: "boom")
    expect(embedder.embed("q")).to be_nil
  end

  it "raises on a dimension mismatch while indexing so the job retries" do
    stub_service(status: 200, body: { embeddings: [[0.1, 0.2]], dim: 2 }.to_json)
    expect { embedder.embed_batch(["x"]) }.to raise_error(/dim mismatch/)
  end

  it "returns an empty array without calling the service for empty input" do
    expect(Net::HTTP).not_to receive(:new)
    expect(embedder.embed_batch([])).to eq([])
  end
end
