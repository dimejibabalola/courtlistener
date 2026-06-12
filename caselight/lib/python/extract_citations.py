#!/usr/bin/env python3
"""Citation extraction shim around eyecite (Free Law Project).

Reads document text on stdin, writes a JSON array of citations on stdout.
Each entry: raw, kind, volume, reporter, page, section, pin_cite, case_name,
position, year, resolved_index (index of the antecedent full citation for
short forms, or null).

Invoked by Citations::EyeciteParser; keep the output shape in sync with it.
"""
import json
import sys

from eyecite import get_citations, resolve_citations
from eyecite.models import (
    FullCaseCitation,
    FullLawCitation,
    IdCitation,
    ShortCaseCitation,
    SupraCitation,
)


def kind_of(citation):
    if isinstance(citation, FullCaseCitation):
        return "case_full"
    if isinstance(citation, ShortCaseCitation):
        return "case_short"
    if isinstance(citation, IdCitation):
        return "id_cite"
    if isinstance(citation, SupraCitation):
        return "supra_cite"
    if isinstance(citation, FullLawCitation):
        reporter = (citation.groups or {}).get("reporter") or ""
        return "regulation" if "C.F.R." in reporter else "statute"
    return "unknown"


def case_name(citation):
    meta = citation.metadata
    plaintiff = getattr(meta, "plaintiff", None)
    defendant = getattr(meta, "defendant", None)
    if plaintiff and defendant:
        return f"{plaintiff} v. {defendant}"
    return getattr(meta, "antecedent_guess", None)


def main():
    text = sys.stdin.read()
    citations = get_citations(text)
    index_of = {id(c): i for i, c in enumerate(citations)}

    antecedent = {}
    for _resource, cluster in resolve_citations(citations).items():
        full_index = None
        for c in cluster:
            if isinstance(c, (FullCaseCitation, FullLawCitation)):
                full_index = index_of[id(c)]
                break
        if full_index is None:
            continue
        for c in cluster:
            i = index_of[id(c)]
            if i != full_index:
                antecedent[i] = full_index

    out = []
    for i, c in enumerate(citations):
        groups = c.groups or {}
        meta = c.metadata
        reporter = groups.get("reporter")
        corrected = getattr(c, "corrected_reporter", None)
        if callable(corrected):
            try:
                reporter = c.corrected_reporter() or reporter
            except Exception:  # noqa: BLE001 - reporter correction is best-effort
                pass
        span = c.span()
        out.append(
            {
                "raw": c.matched_text(),
                "kind": kind_of(c),
                "volume": groups.get("volume"),
                "reporter": reporter,
                "page": groups.get("page"),
                "section": groups.get("section"),
                "title": groups.get("title") or groups.get("volume") or groups.get("chapter"),
                "pin_cite": getattr(meta, "pin_cite", None),
                "case_name": case_name(c),
                "position": span[0],
                "year": getattr(meta, "year", None),
                "resolved_index": antecedent.get(i),
            }
        )
    json.dump(out, sys.stdout)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 - report and signal failure to the caller
        print(f"eyecite extraction failed: {exc}", file=sys.stderr)
        sys.exit(3)
