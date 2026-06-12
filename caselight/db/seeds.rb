# Demo corpus. All cases, parties, judges, opinions, headnotes and summaries
# are ORIGINAL FICTION written for this project — citations like
# "987 F.3d 1234" are deliberately impossible/placeholder values. Do not rely
# on anything here as law.

require "faker"

Faker::Config.random = Random.new(2026)
srand(2026)

puts "==> Seeding Caselight demo corpus"

# Run enqueued callbacks (treatment recompute) synchronously while seeding.
ActiveJob::Base.queue_adapter = :inline

# Bulk ingest uses the fast pure-Ruby parser; the brief analysis at the end
# switches back to eyecite to exercise the production path.
previous_parser = ENV["CITATION_PARSER"]
ENV["CITATION_PARSER"] = "ruby"

ActiveRecord::Base.transaction do
  # --- Workspace -----------------------------------------------------------
  firm = Organization.find_or_create_by!(name: "Parker & Voss LLP") { |o| o.slug = "parker-voss" }

  alex = User.find_or_initialize_by(email: "alex@example.com")
  alex.assign_attributes(
    password: "password123", full_name: "Alex Parker", role: :admin,
    organization: firm, ai_provider: "deepseek",
    ai_model: ENV.fetch("DEEPSEEK_MODEL", "deepseek-chat"),
    settings: { "default_scope" => "all", "results_per_page" => "20" }
  )
  alex.save!

  jordan = User.find_or_initialize_by(email: "jordan@example.com")
  jordan.assign_attributes(password: "password123", full_name: "Jordan Voss", organization: firm)
  jordan.save!

  # --- Jurisdictions & courts ---------------------------------------------
  federal = Jurisdiction.find_or_create_by!(slug: "federal") { |j| j.name = "Federal"; j.kind = :federal }
  states = {}
  { "illinois" => "Illinois", "california" => "California", "north-carolina" => "North Carolina",
    "delaware" => "Delaware", "new-york" => "New York", "texas" => "Texas" }.each do |slug, name|
    states[slug] = Jurisdiction.find_or_create_by!(slug:) { |j| j.name = name; j.kind = :state }
  end

  courts = {}
  make_court = lambda do |slug, attrs|
    courts[slug] = Court.find_or_create_by!(slug:) { |c| c.assign_attributes(attrs) }
  end
  make_court.call("scotus", name: "Supreme Court of the United States", abbreviation: "U.S.", level: :supreme, jurisdiction: federal)
  make_court.call("ca7", name: "United States Court of Appeals, Seventh Circuit", abbreviation: "7th Cir.", level: :appellate, jurisdiction: federal)
  make_court.call("ca3", name: "United States Court of Appeals, Third Circuit", abbreviation: "3d Cir.", level: :appellate, jurisdiction: federal)
  make_court.call("ca2", name: "United States Court of Appeals, Second Circuit", abbreviation: "2d Cir.", level: :appellate, jurisdiction: federal)
  make_court.call("ca9", name: "United States Court of Appeals, Ninth Circuit", abbreviation: "9th Cir.", level: :appellate, jurisdiction: federal)
  make_court.call("nd-ill", name: "United States District Court, Northern District of Illinois", abbreviation: "N.D. Ill.", level: :trial, jurisdiction: federal, parent: courts["ca7"])
  make_court.call("cal-app", name: "California Court of Appeal", abbreviation: "Cal. Ct. App.", level: :appellate, jurisdiction: states["california"])
  make_court.call("nc-app", name: "North Carolina Court of Appeals", abbreviation: "N.C. Ct. App.", level: :appellate, jurisdiction: states["north-carolina"])
  make_court.call("del-ch", name: "Delaware Court of Chancery", abbreviation: "Del. Ch.", level: :trial, jurisdiction: states["delaware"])
  make_court.call("ny-app", name: "New York Appellate Division", abbreviation: "N.Y. App. Div.", level: :appellate, jurisdiction: states["new-york"])
  make_court.call("tex-app", name: "Texas Court of Appeals", abbreviation: "Tex. App.", level: :appellate, jurisdiction: states["texas"])

  # --- Judges ---------------------------------------------------------------
  judge_names = {
    "ca7" => %w[Posner Easterbrook Hamilton Wood Rovner],
    "ca3" => %w[Marsh Okafor Lindqvist],
    "ca2" => %w[Devereaux Quint Abara],
    "ca9" => %w[Whitfield Ramos Chen],
    "cal-app" => %w[Navarro Ellington Pham],
    "nc-app" => %w[Holloway Banks Tarleton],
    "del-ch" => %w[Mercer Vale],
    "scotus" => %w[Calloway Iverson]
  }
  judges = {}
  judge_names.each do |court_slug, names|
    names.each do |name|
      judges[name] = Judge.find_or_create_by!(slug: name.parameterize) { |j| j.name = name; j.court = courts[court_slug] }
    end
  end
  judge_pool = judges.values

  # --- Topic taxonomy (original codes) --------------------------------------
  make_topic = lambda do |code, name, parent: nil, position: 0|
    Topic.find_or_create_by!(code:) do |t|
      t.name = name
      t.parent = parent
      t.depth = parent ? parent.depth + 1 : 0
      t.position = position
    end
  end

  bus = make_topic.call("BUS", "Business Organizations", position: 1)
  corp = make_topic.call("BUS.CORP", "Corporations", parent: bus, position: 1)
  veil = make_topic.call("BUS.CORP.VEIL", "Piercing the Corporate Veil", parent: corp, position: 1)
  alter_ego = make_topic.call("BUS.CORP.VEIL.010", "Alter Ego Doctrine", parent: veil, position: 1)
  instrumentality = make_topic.call("BUS.CORP.VEIL.020", "Instrumentality Rule", parent: veil, position: 2)
  undercap = make_topic.call("BUS.CORP.VEIL.030", "Undercapitalization", parent: veil, position: 3)
  fraud_prong = make_topic.call("BUS.CORP.VEIL.040", "Fraud or Injustice Requirement", parent: veil, position: 4)
  commingling = make_topic.call("BUS.CORP.VEIL.050", "Commingling of Assets", parent: veil, position: 5)
  formalities = make_topic.call("BUS.CORP.VEIL.060", "Corporate Formalities", parent: veil, position: 6)
  separateness = make_topic.call("BUS.CORP.SEP", "Corporate Separateness", parent: corp, position: 2)
  make_topic.call("BUS.CORP.SEP.010", "Limited Liability Principle", parent: separateness, position: 1)
  gov = make_topic.call("BUS.CORP.GOV", "Corporate Governance", parent: corp, position: 3)
  make_topic.call("BUS.CORP.GOV.010", "Fiduciary Duties", parent: gov, position: 1)
  make_topic.call("BUS.CORP.GOV.020", "Business Judgment Rule", parent: gov, position: 2)
  llc = make_topic.call("BUS.LLC", "Limited Liability Companies", parent: bus, position: 2)
  llc_veil = make_topic.call("BUS.LLC.010", "Veil Piercing of LLCs", parent: llc, position: 1)
  civ = make_topic.call("CIV", "Civil Procedure", position: 2)
  juris = make_topic.call("CIV.JUR", "Jurisdiction", parent: civ, position: 1)
  diversity = make_topic.call("CIV.JUR.010", "Diversity Jurisdiction", parent: juris, position: 1)
  pleading = make_topic.call("CIV.PLD", "Pleading Standards", parent: civ, position: 2)
  contracts = make_topic.call("CON", "Contracts", position: 3)
  make_topic.call("CON.FRM", "Contract Formation", parent: contracts, position: 1)
  sec = make_topic.call("SEC", "Securities Regulation", position: 4)
  sec_fraud = make_topic.call("SEC.FRD", "Securities Fraud", parent: sec, position: 1)

  # --- Helper to build a case ------------------------------------------------
  build_case = lambda do |title:, cite:, court:, decided_on:, **attrs|
    citations = Array(attrs.delete(:parallel_cites)).dup.prepend(cite)
    doc = Case.create!(
      title:, court:, jurisdiction: court.jurisdiction, decided_on:,
      primary_citation: cite, practice_area: attrs.delete(:practice_area) || "Business Organizations",
      source_name: "Caselight demo corpus", **attrs
    )
    citations.each { |raw| doc.citations.create!(raw:) }
    doc
  end

  # --- The featured case: Anderson v. Summit Holdings -----------------------
  anderson_text = <<~OPINION
    POSNER, Circuit Judge.

    Dana Anderson invested $2.4 million in Summit Holdings, Inc., a closely held Illinois corporation whose chief executive and sole shareholder, Mark Summit, promised that the funds would capitalize a logistics venture. The district court found that Summit instead routed the money through Summit Holdings to his personal accounts, paid no salaries, kept no minutes, and issued no stock ledger entries. When Anderson obtained a judgment against the corporation, it was an empty shell. The district court pierced the corporate veil and held Summit personally liable. We affirm.

    The corporate form is not a talisman. Illinois law permits a court to disregard the corporate entity where there is such unity of interest and ownership that the separate personalities of the corporation and the individual no longer exist, and where adherence to the fiction of separate corporate existence would sanction a fraud or promote injustice. We applied that standard in Calloway Industrial Supply Co. v. Brennan Metals, Inc., 612 F.3d 401, 408 (7th Cir. 2010), and nothing in this record calls for a different approach.

    Summit urges that ownership and control, without more, cannot justify piercing. That is true, and the district court said as much. See Halvorsen v. Crown Pacific Partners, 559 F.3d 220, 226 (7th Cir. 2009) (mere ownership and control are insufficient). But the court went on to find misuse: commingled accounts, fictitious invoices, and a pattern of draining corporate assets the moment creditors appeared. The instrumentality rule asks whether the corporation was operated as a mere conduit for the shareholder's personal affairs. It was.

    Summit also leans on In re Fairfield Manufacturing Corp., 654 F.3d 789, 795 (3d Cir. 2018), where the Third Circuit declined to pierce on common ownership alone. We distinguish Fairfield, which involved an adequately capitalized subsidiary observing corporate formalities. Summit Holdings observed none. Undercapitalization is not by itself dispositive, but deliberate undercapitalization coupled with fraudulent representations to an investor is precisely the inequity the doctrine exists to remedy. Accord Lopez v. Global Tech Solutions, LLC, 202 Cal. App. 5th 321, 330 (Cal. Ct. App. 2020).

    Anderson proved reliance on Summit's representations, proved that the corporation was Summit's instrumentality, and proved injury flowing from the misuse. Federal jurisdiction rested on diversity, 28 U.S.C. § 1332, and Illinois supplies the rule of decision. The judgment piercing the corporate veil and imposing personal liability on Mark Summit is

    AFFIRMED.
  OPINION

  anderson = build_case.call(
    title: "Anderson v. Summit Holdings, Inc.",
    cite: "987 F.3d 1234",
    court: courts["ca7"],
    decided_on: Date.new(2021, 12, 14),
    argued_on: Date.new(2021, 9, 22),
    docket_number: "20-1234",
    lower_court: courts["nd-ill"],
    lower_court_docket: "1:19-cv-5678",
    author_judge: judges["Posner"],
    panel_text: "Posner, Easterbrook, and Hamilton, Circuit Judges.",
    primary_topic: veil,
    full_text: anderson_text,
    summary: "The Seventh Circuit affirms the district court's judgment piercing the corporate veil and imposing personal liability on the individual shareholder. The court holds that the plaintiff established that the corporation was the shareholder's instrumentality, used to perpetrate a fraud and injustice, and that respecting the corporate form would sanction a wrongful act. Mere ownership and control are insufficient; there must be misuse of the entity that causes injury.",
    issue: "Whether the district court erred in piercing the corporate veil to hold the sole shareholder personally liable for the corporation's obligations.",
    holding: "No. The court held that the shareholder so dominated and misused the corporation to perpetrate a fraud and injustice that the corporate veil may be pierced.",
    key_facts: [
      "Anderson invested in Summit Holdings based on representations by CEO and sole shareholder Mark Summit.",
      "Funds were diverted to Summit's personal accounts and used for non-corporate expenses.",
      "Summit undercapitalized the company and failed to follow corporate formalities.",
      "Anderson suffered losses and obtained a judgment against Summit Holdings."
    ],
    disposition: "Affirmed"
  )
  [judges["Posner"], judges["Easterbrook"], judges["Hamilton"]].each_with_index do |judge, i|
    anderson.case_judges.create!(judge:, role: i.zero? ? :author : :panel)
  end
  [["Dana Anderson", :appellee], ["Summit Holdings, Inc.", :appellant], ["Mark Summit", :appellant]].each do |name, role|
    anderson.case_parties.create!(party: Party.find_or_create_by!(name:), role:)
  end
  [["Priya Raman", "Raman & Cole LLP", :appellee], ["Theodore Brandt", "Brandt Litigation Group", :appellant]].each do |name, firm_name, side|
    anderson.case_attorneys.create!(attorney: Attorney.find_or_create_by!(name:) { |a| a.firm_name = firm_name }, representing: side)
  end

  [
    [1, "A court may disregard the corporate entity where there is such unity of interest and ownership that separate personalities of corporation and shareholder no longer exist, and adherence to the corporate fiction would sanction fraud or promote injustice.", [veil, alter_ego]],
    [2, "Mere ownership and control of a corporation by a single shareholder is insufficient, standing alone, to pierce the corporate veil.", [veil, separateness]],
    [3, "Operating a corporation as a mere conduit for a shareholder's personal affairs satisfies the instrumentality prong of the veil-piercing analysis.", [instrumentality]],
    [4, "Deliberate undercapitalization, coupled with fraudulent representations to investors, supports the inequity prong of veil piercing.", [undercap, fraud_prong]],
    [5, "Commingling corporate and personal accounts and disregarding corporate formalities are probative of alter ego status.", [commingling, formalities]],
    [6, "A federal court sitting in diversity applies the forum state's standard for piercing the corporate veil.", [diversity, veil]]
  ].each do |number, text, topics_list|
    headnote = anderson.headnotes.create!(number:, text:)
    topics_list.each { |t| headnote.headnote_topics.create!(topic: t) }
  end

  # --- The other three named results ----------------------------------------
  fairfield = build_case.call(
    title: "In re Fairfield Manufacturing Corp.",
    cite: "654 F.3d 789",
    court: courts["ca3"],
    decided_on: Date.new(2018, 8, 7),
    docket_number: "17-2210",
    author_judge: judges["Marsh"],
    panel_text: "Marsh, Okafor, and Lindqvist, Circuit Judges.",
    primary_topic: separateness,
    summary: "Reverses a veil-piercing judgment; mere ownership and common control are insufficient without a showing of inequity or fraud. An adequately capitalized subsidiary that observes corporate formalities retains its separate existence.",
    issue: "Whether common ownership and overlapping management alone justify disregarding a subsidiary's separate corporate existence.",
    holding: "No. Absent inequity, fraud, or misuse of the corporate form, common ownership and control do not permit veil piercing.",
    key_facts: [
      "Creditors sought to reach the parent's assets for the subsidiary's contract debts.",
      "The subsidiary was adequately capitalized and kept separate books and records.",
      "No evidence showed assets were diverted or formalities ignored."
    ],
    full_text: <<~OPINION,
      MARSH, Circuit Judge.

      The bankruptcy court pierced the corporate veil between Fairfield Manufacturing Corp. and its parent on findings of common ownership and overlapping officers. That is not enough. Limited liability is the rule, not the exception, and a creditor who would disregard the corporate form must show that the form itself was misused to work an inequity.

      Fairfield observed corporate formalities, maintained separate accounts, and was capitalized commensurately with its operations. The trustee identified no commingling, no asset stripping, and no misrepresentation. Common control is a feature of corporate groups, not a fraud. The judgment piercing the veil is REVERSED.
    OPINION
    disposition: "Reversed"
  )

  lopez = build_case.call(
    title: "Lopez v. Global Tech Solutions, LLC",
    cite: "202 Cal. App. 5th 321",
    court: courts["cal-app"],
    decided_on: Date.new(2020, 3, 3),
    docket_number: "B298811",
    author_judge: judges["Navarro"],
    panel_text: "Navarro, Ellington, and Pham, Justices.",
    primary_topic: alter_ego,
    summary: "Affirms imposition of personal liability under the alter ego doctrine where the member commingled funds and misused the limited liability form of the entity.",
    issue: "Whether substantial evidence supported alter ego liability against the managing member of an LLC.",
    holding: "Yes. Commingling of funds, disregard of the entity's separateness, and resulting injustice support alter ego liability.",
    key_facts: [
      "The managing member paid personal expenses directly from company accounts.",
      "Company and personal funds were commingled in a single account.",
      "Creditors were left unpaid while distributions continued."
    ],
    full_text: <<~OPINION,
      NAVARRO, J.

      Substantial evidence supports the trial court's finding that Global Tech Solutions, LLC was the alter ego of its managing member. The member commingled funds, treated company accounts as his own, and continued distributions while trade creditors went unpaid. Recognizing the entity's separateness on these facts would promote injustice. We affirm the judgment imposing personal liability.
    OPINION
    disposition: "Affirmed"
  )

  bird = build_case.call(
    title: "Bird v. Phoenix Ventures, Inc.",
    cite: "812 S.E.2d 45",
    court: courts["nc-app"],
    decided_on: Date.new(2019, 1, 15),
    docket_number: "COA18-744",
    author_judge: judges["Holloway"],
    panel_text: "Holloway, Banks, and Tarleton, Judges.",
    primary_topic: instrumentality,
    summary: "Applies the instrumentality rule to affirm veil piercing where the parent exercised complete domination over the subsidiary's finances and policy with respect to the transaction attacked.",
    issue: "Whether the instrumentality rule supports piercing where domination relates to the specific transaction at issue.",
    holding: "Yes, where complete domination was used to commit a wrong that proximately injured the plaintiff.",
    key_facts: [
      "The parent dictated every financial decision of the subsidiary.",
      "The subsidiary had no independent business purpose.",
      "The transaction at issue was structured to defeat the plaintiff's recovery."
    ],
    full_text: <<~OPINION,
      HOLLOWAY, Judge.

      North Carolina applies the instrumentality rule. The evidence showed complete domination of Phoenix Ventures' finances and policy as to the transaction attacked, use of that domination to commit a wrong, and proximate injury. The judgment is affirmed.
    OPINION
    disposition: "Affirmed"
  )

  # --- Statutes / regulation / secondary source ------------------------------
  statute1 = Statute.create!(
    title: "28 U.S.C. § 1332 — Diversity of citizenship", primary_citation: "28 U.S.C. § 1332",
    jurisdiction: federal, decided_on: Date.new(2011, 12, 7), practice_area: "Civil Procedure",
    primary_topic: diversity, source_name: "Caselight demo corpus",
    summary: "Grants district courts original jurisdiction of civil actions between citizens of different states where the amount in controversy exceeds $75,000.",
    full_text: "The district courts shall have original jurisdiction of all civil actions where the matter in controversy exceeds the sum or value of $75,000, exclusive of interest and costs, and is between citizens of different States…"
  )
  statute1.citations.create!(raw: "28 U.S.C. § 1332", kind: :statute)

  statute2 = Statute.create!(
    title: "15 U.S.C. § 78j — Manipulative and deceptive devices", primary_citation: "15 U.S.C. § 78j",
    jurisdiction: federal, decided_on: Date.new(1934, 6, 6), practice_area: "Securities Regulation",
    primary_topic: sec_fraud, source_name: "Caselight demo corpus",
    summary: "Prohibits the use of manipulative or deceptive devices in connection with the purchase or sale of securities.",
    full_text: "It shall be unlawful for any person, directly or indirectly… to use or employ, in connection with the purchase or sale of any security… any manipulative or deceptive device or contrivance…"
  )
  statute2.citations.create!(raw: "15 U.S.C. § 78j", kind: :statute)

  regulation = Regulation.create!(
    title: "17 C.F.R. § 240.10b-5 — Employment of manipulative and deceptive devices",
    primary_citation: "17 C.F.R. § 240.10b-5", jurisdiction: federal,
    decided_on: Date.new(1948, 5, 21), practice_area: "Securities Regulation",
    primary_topic: sec_fraud, source_name: "Caselight demo corpus",
    summary: "Makes it unlawful to make untrue statements of material fact or to engage in acts that operate as a fraud in connection with securities transactions.",
    full_text: "It shall be unlawful for any person… (a) To employ any device, scheme, or artifice to defraud, (b) To make any untrue statement of a material fact… or (c) To engage in any act, practice, or course of business which operates or would operate as a fraud or deceit upon any person, in connection with the purchase or sale of any security."
  )
  regulation.citations.create!(raw: "17 C.F.R. § 240.10b-5", kind: :regulation)

  secondary = SecondarySource.create!(
    title: "Harmon & Wei, Shareholder Liability After Anderson: Mapping the Instrumentality Rule",
    primary_citation: "44 Caselight J. Corp. Stud. 201", jurisdiction: federal,
    decided_on: Date.new(2022, 4, 1), practice_area: "Business Organizations", primary_topic: veil,
    source_name: "Caselight demo corpus",
    summary: "Law review survey of veil-piercing outcomes after Anderson v. Summit Holdings, identifying undercapitalization plus misrepresentation as the dominant fact pattern in successful claims.",
    full_text: "This survey reviews three hundred veil-piercing decisions issued after Anderson v. Summit Holdings, Inc., 987 F.3d 1234 (7th Cir. 2021), and finds that courts pierce most readily where deliberate undercapitalization is paired with misrepresentation to creditors or investors…"
  )
  secondary.citations.create!(raw: "44 Caselight J. Corp. Stud. 201", kind: :parallel)

  # Authorities Anderson itself cites (so its outbound edges resolve).
  calloway = build_case.call(
    title: "Calloway Industrial Supply Co. v. Brennan Metals, Inc.",
    cite: "612 F.3d 401", court: courts["ca7"], decided_on: Date.new(2010, 7, 19),
    author_judge: judges["Easterbrook"], primary_topic: veil,
    summary: "Sets out the two-prong Illinois standard for piercing the corporate veil: unity of interest and ownership, plus fraud or injustice from respecting the corporate form.",
    holding: "Veil piercing requires unity of interest and ownership and a resulting fraud or injustice.",
    full_text: "EASTERBROOK, Circuit Judge. Illinois permits courts to disregard the corporate entity where unity of interest and ownership erases the separate personalities of corporation and shareholder and where honoring the form would sanction fraud or promote injustice…"
  )
  halvorsen = build_case.call(
    title: "Halvorsen v. Crown Pacific Partners",
    cite: "559 F.3d 220", court: courts["ca7"], decided_on: Date.new(2009, 3, 2),
    author_judge: judges["Wood"], primary_topic: separateness,
    summary: "Mere ownership and control of a corporation are insufficient to pierce the corporate veil absent misuse of the corporate form.",
    holding: "Ownership and control alone do not justify piercing the corporate veil.",
    full_text: "WOOD, Circuit Judge. Ownership and control, without misuse, do not authorize disregarding the corporate form. The corporate veil protects shareholders who respect the entity's separateness…"
  )

  # An overruled authority, so the corpus carries a genuine red flag and the
  # demo brief surfaces a negative row.
  crane = build_case.call(
    title: "Crane v. Vortex Industries, Inc.",
    cite: "88 N.E.3d 410", court: courts["ny-app"], decided_on: Date.new(2008, 6, 17),
    author_judge: judges["Devereaux"], primary_topic: veil,
    summary: "Held that undercapitalization alone suffices to pierce the corporate veil. Later overruled by Mercado v. Atlas Freight Lines.",
    holding: "Undercapitalization alone justifies piercing the corporate veil.",
    full_text: "DEVEREAUX, J. We hold that undercapitalization alone is a sufficient basis for piercing the corporate veil…",
    practice_area: "Business Organizations"
  )
  mercado = build_case.call(
    title: "Mercado v. Atlas Freight Lines, Inc.",
    cite: "194 N.Y.S.3d 77", court: courts["ny-app"], decided_on: Date.new(2023, 10, 12),
    author_judge: judges["Quint"], primary_topic: veil,
    summary: "Overrules Crane v. Vortex Industries; undercapitalization alone does not justify piercing absent misuse of the corporate form.",
    holding: "Undercapitalization alone does not justify veil piercing; Crane is overruled.",
    full_text: "QUINT, J. To the extent Crane v. Vortex Industries, Inc., 88 N.E.3d 410 (2008), held that undercapitalization alone suffices to pierce the corporate veil, it is overruled. The doctrine requires misuse of the corporate form working an injustice…"
  )
  CitingReference.create!(citing_document: mercado, cited_document: crane,
                          treatment: :overruled, depth: :extended,
                          passage: "To the extent Crane held that undercapitalization alone suffices, it is overruled.")

  # --- 128 citing cases for Anderson (image: Positive 112, Distinguished 7,
  # --- Followed 39, Overruled 0, Cited By 128) -------------------------------
  treatments_plan =
    Array.new(39, :followed) + Array.new(35, :cited_favorably) + Array.new(29, :cited) +
    Array.new(9, :explained) + Array.new(7, :distinguished) + Array.new(5, :criticized) +
    Array.new(4, :questioned)
  treatments_plan.shuffle!(random: Random.new(7))

  passage_templates = {
    followed: "We follow Anderson v. Summit Holdings, Inc., 987 F.3d 1234, %s (7th Cir. 2021), and hold that domination coupled with misuse of the corporate form supports piercing.",
    cited_favorably: "The reasoning of Anderson v. Summit Holdings, Inc., 987 F.3d 1234, %s (7th Cir. 2021), is persuasive: limited liability yields where the entity is a vehicle for inequity.",
    cited: "See Anderson v. Summit Holdings, Inc., 987 F.3d 1234, %s (7th Cir. 2021).",
    explained: "Anderson v. Summit Holdings, Inc., 987 F.3d 1234, %s (7th Cir. 2021), explained that the instrumentality inquiry focuses on misuse, not mere control.",
    distinguished: "Anderson v. Summit Holdings, Inc., 987 F.3d 1234, %s (7th Cir. 2021), is distinguishable; the entity here was adequately capitalized and observed formalities.",
    criticized: "We are not persuaded by the breadth of Anderson v. Summit Holdings, Inc., 987 F.3d 1234, %s (7th Cir. 2021); it has been criticized as collapsing the two prongs into one.",
    questioned: "Whether Anderson v. Summit Holdings, Inc., 987 F.3d 1234, %s (7th Cir. 2021), survives our later cases has been questioned, and we need not resolve that here."
  }

  veil_topics = [veil, alter_ego, instrumentality, undercap, fraud_prong, commingling, formalities, llc_veil]
  citing_courts = %w[ca7 ca2 ca3 ca9 nd-ill cal-app nc-app del-ch ny-app tex-app]
  reporters_by_court = {
    "ca7" => "F.4th", "ca2" => "F.4th", "ca3" => "F.4th", "ca9" => "F.4th",
    "nd-ill" => "F. Supp. 3d", "cal-app" => "Cal. App. 5th", "nc-app" => "S.E.2d",
    "del-ch" => "A.3d", "ny-app" => "N.Y.S.3d", "tex-app" => "S.W.3d"
  }

  company_suffixes = ["Holdings, Inc.", "Industries, Inc.", "Group, LLC", "Partners, L.P.", "Logistics Corp.", "Capital, LLC", "Manufacturing Co.", "Ventures, Inc."]
  surnames = %w[Abara Bell Calder Donovan Egan Farrow Geist Hooper Iqbal Joon Keller Lim Moreau Nash Obi Pruitt Quezada Rourke Sato Tanaka Urban Vance Wilde Xiong Yates Zell Arden Brock Cline Dempsey]

  puts "    creating 128 citing cases for Anderson…"
  citing_cases = treatments_plan.each_with_index.map do |treatment, i|
    court_slug = citing_courts[i % citing_courts.size]
    court = courts[court_slug]
    reporter = reporters_by_court[court_slug]
    volume = 110 + i
    page = 200 + ((i * 37) % 700)
    pin = 1236 + (i % 12)
    decided = Date.new(2022, 1, 5) + (i * 11)
    plaintiff = surnames[i % surnames.size]
    defendant = "#{surnames[(i * 7 + 3) % surnames.size]} #{company_suffixes[i % company_suffixes.size]}"
    passage = format(passage_templates.fetch(treatment), pin)
    topic = veil_topics[i % veil_topics.size]

    body = <<~TEXT
      The question is whether the corporate veil of #{defendant} may be pierced. #{passage}

      #{Faker::Lorem.paragraph(sentence_count: 4)} The record here shows #{%w[commingled separate][i % 2]} accounts and #{['no', 'scrupulous'][i % 2]} observance of corporate formalities.

      #{Faker::Lorem.paragraph(sentence_count: 3)}
    TEXT

    doc = build_case.call(
      title: "#{plaintiff} v. #{defendant}",
      cite: "#{volume} #{reporter} #{page}",
      court:, decided_on: decided,
      author_judge: judge_pool[i % judge_pool.size],
      primary_topic: topic,
      summary: passage,
      full_text: body
    )

    CitingReference.create!(
      citing_document: doc, cited_document: anderson, treatment:,
      depth: [:passing, :discussed, :significant, :extended][i % 4],
      pin_cite: pin.to_s, passage: passage
    )
    doc
  end

  # Treatment edges for the other named cases.
  edge_specs = [[fairfield, :distinguished], [fairfield, :followed], [bird, :questioned],
                [bird, :followed], [lopez, :followed], [lopez, :cited_favorably],
                [calloway, :followed], [halvorsen, :cited], [secondary, :cited]]
  citing_cases.each_slice(9).with_index do |slice, batch|
    target, treatment = edge_specs[batch % edge_specs.size]
    slice.first(3).each do |doc|
      next if doc == target

      CitingReference.find_or_create_by!(citing_document: doc, cited_document: target) do |ref|
        ref.treatment = treatment
        ref.depth = :discussed
        ref.passage = "Discussing #{target.title}."
      end
    end
  end

  # --- Background corpus across other practice areas ------------------------
  puts "    creating background corpus…"
  background_topics = { "Civil Procedure" => [juris, diversity, pleading], "Contracts" => [contracts], "Securities Regulation" => [sec_fraud] }
  background_areas = background_topics.keys
  40.times do |i|
    area = background_areas[i % background_areas.size]
    court_slug = citing_courts[(i * 3) % citing_courts.size]
    court = courts[court_slug]
    build_case.call(
      title: "#{surnames[(i * 3) % surnames.size]} v. #{Faker::Company.name.gsub(/[^A-Za-z0-9 .,&'-]/, '')}",
      cite: "#{300 + i} #{reporters_by_court[court_slug]} #{(50 + i * 13) % 800 + 10}",
      court:, decided_on: Date.new(1995, 1, 1) + (i * 271),
      primary_topic: background_topics[area][i % background_topics[area].size],
      practice_area: area,
      summary: Faker::Lorem.paragraph(sentence_count: 2),
      full_text: Faker::Lorem.paragraphs(number: 5).join("\n\n")
    )
  end

  # --- Workspace content -----------------------------------------------------
  puts "    folders, matter, notes, pins, history…"
  matter = Matter.create!(
    user: alex, organization: firm, name: "Meridian Capital v. Stratton Group",
    matter_number: "2026-0041", status: :active,
    description: "Investor suit seeking to pierce Stratton Group's corporate veil; tracking authority on undercapitalization and instrumentality."
  )

  folder_specs = {
    "Piercing the Corporate Veil" => [anderson, lopez, bird, calloway, secondary],
    "Shareholder Liability" => [anderson, halvorsen, fairfield],
    "Alter Ego Doctrine" => [lopez, anderson],
    "Instrumentality Cases" => [bird, calloway]
  }
  folders = folder_specs.map do |name, docs|
    folder = Folder.create!(user: alex, name:, matter: (name == "Piercing the Corporate Veil" ? matter : nil), shared: true)
    docs.each { |d| folder.add(d, added_by: alex) }
    folder
  end
  citing_cases.first(20).each_with_index do |doc, i|
    folders[i % folders.size].add(doc, added_by: i.even? ? alex : jordan)
  end

  anderson.annotations.create!(
    user: alex, kind: :note, created_at: Time.zone.local(2026, 5, 10, 14, 5),
    body: "Good discussion of the fraud / injustice prong. Distinguish from cases with adequate capitalization."
  )
  anderson.annotations.create!(
    user: alex, kind: :highlight, created_at: Time.zone.local(2026, 5, 12, 9, 40),
    quote: "Mere ownership and control are insufficient; there must be misuse of the entity that causes injury.",
    body: "Lead with this framing in the reply brief."
  )

  alex.pins.create!(document: anderson, position: 1)
  alex.pins.create!(document: lopez, position: 2)

  alex.saved_searches.create!(
    name: "Veil piercing — new authority", query: "piercing the corporate veil",
    filters: {}, alerts_enabled: true, last_run_at: 2.days.ago, last_results_count: 120,
    seen_document_ids: citing_cases.first(110).map(&:id)
  )
  alex.saved_searches.create!(name: "Undercapitalization + fraud", query: %(undercapital! AND fraud /p veil), filters: {}, alerts_enabled: false)

  ["piercing the corporate veil", "alter ego doctrine California", %("alter ego" AND commingl!), "987 F.3d 1234"].each_with_index do |q, i|
    alex.search_histories.create!(query: q, query_type: %w[natural natural boolean citation][i],
                                  results_count: [134, 58, 41, 1][i], created_at: (4 - i).hours.ago)
  end
  [anderson, fairfield, lopez].each { |doc| DocumentView.record!(alex, doc) }

  draft = alex.drafts.create!(
    matter:, document: anderson, title: "Memo — veil piercing standard (7th Cir.)",
    tone: "neutral",
    body: "<p>The Seventh Circuit has affirmed veil piercing where the shareholder used the corporation as an instrumentality to perpetrate a fraud or injustice. <em>Anderson v. Summit Holdings, Inc.</em>, 987 F.3d 1234, 1241 (7th Cir. 2021).</p>"
  )
  folders.first.add(draft, added_by: alex)

  # 12 unread notifications (matches the bell badge in the design).
  citing_cases.last(11).each_with_index do |doc, i|
    alex.notifications.create!(
      kind: :saved_search_alert,
      title: "New result for “Veil piercing — new authority”",
      body: "#{doc.title}, #{doc.display_citation} (#{doc.court&.abbreviation} #{doc.decided_on&.year})",
      url: "/research?q=piercing+the+corporate+veil",
      created_at: (12 - i).hours.ago
    )
  end
  alex.notifications.create!(
    kind: :system, title: "Welcome to Caselight",
    body: "Your workspace is ready. Upload a brief to check its authorities.",
    url: "/uploads", created_at: 2.days.ago
  )

  # --- Demo AI conversation (grounded extractive answer, no API call) -------
  conversation = alex.ai_conversations.create!(context: anderson, provider: "local", model: "caselight-extractive-1", title: "Veil piercing follow-ups")
  conversation.ai_messages.create!(role: :user_role, content: "What must a plaintiff show beyond ownership and control?")
  conversation.ai_messages.create!(
    role: :assistant, provider: "local", model: "caselight-extractive-1",
    content: "Based on the sources retrieved for this question: Mere ownership and control of a corporation by a single shareholder is insufficient, standing alone, to pierce the corporate veil [1]. A court may disregard the corporate entity where unity of interest and ownership erases separateness and adherence to the corporate fiction would sanction fraud or promote injustice [1]. Ownership and control, without misuse, do not authorize disregarding the corporate form [2].",
    sources: [
      { "n" => 1, "document_id" => anderson.id, "title" => anderson.title, "citation" => anderson.display_citation, "quote" => "Mere ownership and control are insufficient…" },
      { "n" => 2, "document_id" => halvorsen.id, "title" => halvorsen.title, "citation" => halvorsen.display_citation, "quote" => "Ownership and control, without misuse, do not authorize disregarding the corporate form." }
    ]
  )
end

# --- Index everything (chunks, embeddings, edges, treatment) ----------------
puts "    indexing corpus (chunks + embeddings)…"
hero_ids = Document.where(title: [
  "Anderson v. Summit Holdings, Inc.", "In re Fairfield Manufacturing Corp.",
  "Lopez v. Global Tech Solutions, LLC", "Bird v. Phoenix Ventures, Inc."
]).pluck(:id).to_set

Document.find_each do |document|
  Search::Indexer.new(document).run!
  Citator::EdgeBuilder.new(document).run! if hero_ids.include?(document.id)
end

puts "    resolving treatment flags…"
Document.find_each { |document| Citator::TreatmentResolver.new(document).resolve! }

# --- Demo brief + analysis (uses eyecite when available) ---------------------
if previous_parser
  ENV["CITATION_PARSER"] = previous_parser
else
  ENV.delete("CITATION_PARSER")
end
puts "    creating demo brief + authority check (parser: #{Citations::Extractor.backend})…"

alex = User.find_by!(email: "alex@example.com")
matter = Matter.find_by!(name: "Meridian Capital v. Stratton Group")
brief_text = <<~BRIEF
  ARGUMENT

  I. THE COURT SHOULD PIERCE STRATTON GROUP'S CORPORATE VEIL.

  Illinois law permits a court to disregard the corporate entity where unity of interest and ownership erases corporate separateness and respecting the form would sanction a fraud or promote injustice. Anderson v. Summit Holdings, Inc., 987 F.3d 1234, 1241 (7th Cir. 2021). The shareholder's domination must be paired with misuse of the entity. Id. at 1242. Ownership and control alone are insufficient. Halvorsen v. Crown Pacific Partners, 559 F.3d 220, 226 (7th Cir. 2009).

  Defendants will rely on In re Fairfield Manufacturing Corp., 654 F.3d 789, 795 (3d Cir. 2018), but Fairfield involved an adequately capitalized subsidiary that observed corporate formalities. Anderson, 987 F.3d at 1244. Here, as in Lopez v. Global Tech Solutions, LLC, 202 Cal. App. 5th 321, 330 (Cal. Ct. App. 2020), the controlling member commingled funds and paid personal expenses from company accounts. Undercapitalization alone also supports piercing. Crane v. Vortex Industries, Inc., 88 N.E.3d 410, 415 (2008).

  Jurisdiction rests on diversity of citizenship. 28 U.S.C. § 1332. Plaintiff's securities claim arises under 17 C.F.R. § 240.10b-5. See also Templeton v. Vasquez Holdings Corp., 444 F.3d 9101, 9109 (7th Cir. 2031) (a citation that should not match anything).

  CONCLUSION

  The Court should enter judgment for Plaintiff. Anderson, supra, at 1245.
BRIEF

upload = alex.uploaded_documents.create!(
  title: "Meridian — Brief in Support of Veil Piercing.pdf",
  kind: :brief, matter:, status: :ready,
  extracted_text: brief_text, ocr_method: "seeded", pages_count: 14
)
analysis = upload.brief_analyses.create!(user: alex)
Briefs::Analyzer.new(analysis).run!

puts "==> Done."
puts "    Sign in: alex@example.com / password123  (admin)"
puts "    Corpus: #{Document.count} documents, #{CitingReference.count} citing references, #{Headnote.count} headnotes"
anderson_doc = Document.find_by(title: "Anderson v. Summit Holdings, Inc.")
puts "    Anderson: cited_by=#{anderson_doc.cited_by_count} treatment=#{anderson_doc.treatment_status}"
puts "    Brief check: #{analysis.authorities_count} authorities — #{analysis.clean_count} clean / #{analysis.cautionary_count} cautionary / #{analysis.negative_count} negative / #{analysis.unmatched_count} unmatched"
