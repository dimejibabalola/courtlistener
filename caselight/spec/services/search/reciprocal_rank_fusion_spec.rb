require "rails_helper"

RSpec.describe Search::ReciprocalRankFusion do
  it "ranks documents appearing high in both lists first" do
    fused = described_class.fuse([1, 2, 3], [3, 1, 4])
    expect(fused.first).to eq(1) # rank 1 + rank 2 beats rank 3 + rank 1
    expect(fused).to contain_exactly(1, 2, 3, 4)
  end

  it "computes the textbook RRF score" do
    # id 7 at rank 1 in one list: 1/(60+1)
    fused = described_class.fuse([7], [])
    expect(fused).to eq([7])
  end

  it "is deterministic on score ties (by id)" do
    expect(described_class.fuse([5], [9])).to eq([5, 9])
    expect(described_class.fuse([9], [5])).to eq([5, 9])
  end

  it "handles empty inputs" do
    expect(described_class.fuse([], [])).to eq([])
    expect(described_class.fuse([1, 2], [])).to eq([1, 2])
  end

  it "weights agreement above single-list dominance" do
    # id 2 is mid-rank in both lists; id 1 only tops one list.
    fused = described_class.fuse([1, 2, 3, 4], [5, 2, 6, 7])
    expect(fused.first).to eq(2)
  end
end
