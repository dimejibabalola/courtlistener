FactoryBot.define do
  factory :jurisdiction do
    sequence(:name) { |n| "Jurisdiction #{n}" }
    kind { :federal }
  end

  factory :court do
    sequence(:name) { |n| "Court of Appeals No. #{n}" }
    sequence(:abbreviation) { |n| "#{n}th Cir." }
    level { :appellate }
    jurisdiction
  end

  factory :judge do
    sequence(:name) { |n| "Judge Quill #{n}" }
  end

  factory :topic do
    sequence(:name) { |n| "Topic #{n}" }
    sequence(:code) { |n| "TST.#{format('%03d', n)}" }
  end

  factory :case_document, class: "Case" do
    sequence(:title) { |n| "Plaintiff v. Defendant No. #{n}" }
    court
    jurisdiction { court.jurisdiction }
    decided_on { Date.new(2020, 6, 1) }
    sequence(:primary_citation) { |n| "#{n + 100} F.4th #{n + 1}" }
    full_text { "The corporate veil may be pierced where the entity is misused. " * 10 }
    summary { "A veil-piercing decision." }

    after(:create) do |document|
      document.citations.create!(raw: document.primary_citation) if document.primary_citation.present?
    end

    trait :indexed do
      after(:create) { |document| Search::Indexer.new(document).rebuild_chunks! }
    end
  end

  factory :statute_document, class: "Statute" do
    sequence(:title) { |n| "#{n} U.S.C. § #{n}00 — Test statute" }
    sequence(:primary_citation) { |n| "#{n} U.S.C. § #{n}00" }
    full_text { "It shall be unlawful…" }

    after(:create) do |document|
      document.citations.create!(raw: document.primary_citation, kind: :statute)
    end
  end

  factory :headnote do
    association :document, factory: :case_document
    sequence(:number) { |n| n }
    text { "A point of law about corporate separateness." }
  end

  factory :citing_reference do
    association :citing_document, factory: :case_document
    association :cited_document, factory: :case_document
    treatment { :cited }
    depth { :passing }
  end

  factory :matter do
    user
    sequence(:name) { |n| "Matter #{n}" }
  end

  factory :folder do
    user
    sequence(:name) { |n| "Folder #{n}" }
  end

  factory :uploaded_document do
    user
    sequence(:title) { |n| "Upload #{n}.pdf" }
    kind { :brief }
    status { :ready }
    extracted_text { "See Anderson v. Summit Holdings, Inc., 987 F.3d 1234 (7th Cir. 2021)." }
  end

  factory :brief_analysis do
    uploaded_document
    user { uploaded_document.user }
  end
end
