#!/usr/bin/env python3
"""
build_compliance_policy.py — generic regulator-policy PDF builder.

Created 2026-05-09 by cline_compliance_templatization (idea #1791)
per Ruben directive 2026-05-08 22:55 PT (CAPCE_2026_PROJECT_MEMORY.md §8).

Usage:
    python3 build_compliance_policy.py \
        --regulator CAPCE \
        --category coi_disclosure \
        --year 2026 \
        --out /Users/rubenmajor/Desktop/CAPCE\ 2026\ Renewal/12a_COI_Disclosure_2026.pdf

Reads the policy body text from a small per-category JSON sidecar at
~/Documents/Cline/Rules/scripts/policy_bodies/<category>.json (one per
policy_category_slug). If the sidecar is missing, emits a structurally-
correct stub the operator fills in by hand or by re-running the builder
after adding the sidecar.

Output convention matches Ruben's standardized /tmp/build_*.py reportlab
pattern from the 2026 CAPCE corpus:
  - Letterhead: EMS UNIVERSITY (centered, #0e3866, 16pt) + subtitle
  - Body: 10.5pt Helvetica, 14pt leading, justified
  - Signature block: signed line + title line + date
  - Reservation language footer: italic 9pt #555

This builder is intentionally generic. Per-policy-category-specific layouts
(e.g. COI disclosure, equipment matrix tables) live in dedicated
build_compliance_<slug>.py builders that import shared header/footer
helpers from this file.
"""

from __future__ import annotations
import argparse
import json
import os
import sys
from datetime import date
from pathlib import Path

try:
    from reportlab.lib.pagesizes import LETTER
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
    from reportlab.platypus import (
        SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem, PageBreak,
    )
    from reportlab.lib.colors import HexColor
except ImportError:
    sys.stderr.write(
        "reportlab not installed. Install with: pip3 install reportlab\n"
    )
    sys.exit(2)

POLICY_BODY_DIR = Path(__file__).parent / "policy_bodies"

REGULATOR_LABELS = {
    "CAPCE":     "Commission on Accreditation for Pre-Hospital Continuing Education (CAPCE)",
    "AZDHS":     "Arizona Department of Health Services — Bureau of EMS (AZDHS BEMS)",
    "CABPPE":    "California Bureau for Private Postsecondary Education (CABPPE)",
    "CA_EMSA":   "California EMS Authority (CA EMSA)",
    "TDSHS":     "Texas Department of State Health Services (TDSHS)",
    "AZPPSE":    "Arizona State Board for Private Postsecondary Education (AZPPSE)",
    "ALAMEDA":   "Alameda County EMS Authority",
    "SAN_DIEGO": "San Diego County EMS Authority",
    "SAN_MATEO": "San Mateo County EMS Authority",
    "NREMT":     "National Registry of Emergency Medical Technicians (NREMT)",
}

DEFAULT_RESERVATION = (
    "EMS University reserves all rights, defenses, and procedural protections. "
    "This document reflects EMS University's current operational policy as of the "
    "review date noted above and may be supplemented or amended in writing. "
    "Provided pursuant to a particularized request by the regulator."
)

DEFAULT_SIGNATURE_BLOCK = (
    "Approved on behalf of EMS University, LLC.<br/><br/>"
    "<br/>__________________________________<br/>"
    "Ruben K. Major<br/>"
    "Chief Executive Officer<br/>"
    "EMS University, LLC<br/>"
    "Date: {today}"
)


def styles():
    base = getSampleStyleSheet()
    return {
        "title":    ParagraphStyle("title",    parent=base["Title"],   fontSize=16, leading=20, alignment=TA_CENTER, textColor=HexColor("#0e3866"), spaceAfter=2),
        "subtitle": ParagraphStyle("sub",      parent=base["Normal"],  fontSize=11, leading=14, alignment=TA_CENTER, textColor=HexColor("#444"),    spaceAfter=14),
        "h2":       ParagraphStyle("h2",       parent=base["Heading2"],fontSize=12, leading=15, textColor=HexColor("#0e3866"), spaceBefore=10, spaceAfter=4),
        "body":     ParagraphStyle("body",     parent=base["BodyText"],fontSize=10.5, leading=14, alignment=TA_JUSTIFY, spaceAfter=6),
        "list":     ParagraphStyle("listitem", parent=base["BodyText"],fontSize=10.5, leading=14, alignment=TA_LEFT, leftIndent=14, spaceAfter=4),
        "footer":   ParagraphStyle("footer",   parent=base["Italic"],  fontSize=9,  leading=11, alignment=TA_LEFT,  textColor=HexColor("#555"), spaceBefore=18),
        "signoff":  ParagraphStyle("signoff",  parent=base["BodyText"],fontSize=10.5, leading=14, alignment=TA_LEFT,  spaceBefore=18),
    }


def load_policy_body(category: str) -> dict | None:
    p = POLICY_BODY_DIR / f"{category}.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except Exception as e:
        sys.stderr.write(f"warning: could not parse {p}: {e}\n")
        return None


def build(regulator: str, category: str, year: int, out_path: Path,
          signature_block: str | None = None,
          reservation_language: str | None = None) -> None:
    s = styles()
    body = load_policy_body(category)
    if body is None:
        body = {
            "title": category.replace("_", " ").title(),
            "intro": (f"This document is the EMS University {category.replace('_',' ')} "
                      f"policy effective for the {year} compliance cycle. The body of this "
                      f"policy will be supplied by the operator before submission. "
                      f"Builder ran in stub mode because no sidecar was found at "
                      f"{POLICY_BODY_DIR / (category + '.json')}."),
            "sections": [
                {"heading": "Scope", "paragraphs": ["Scope statement TBD."]},
                {"heading": "Policy", "paragraphs": ["Policy text TBD."]},
                {"heading": "Records", "paragraphs": ["Records statement TBD."]},
            ],
        }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(out_path), pagesize=LETTER,
        leftMargin=0.85 * inch, rightMargin=0.85 * inch,
        topMargin=0.7 * inch, bottomMargin=0.7 * inch,
        title=body.get("title", category),
    )

    reg_label = REGULATOR_LABELS.get(regulator, regulator)
    sub = body.get("subtitle", f"Submitted to {reg_label} for the {year} compliance cycle")

    story = []
    story.append(Paragraph("EMS UNIVERSITY", s["title"]))
    story.append(Paragraph(body.get("title", category), s["subtitle"]))
    story.append(Paragraph(sub, s["subtitle"]))

    if body.get("intro"):
        story.append(Paragraph(body["intro"], s["body"]))

    for section in body.get("sections", []):
        if section.get("heading"):
            story.append(Paragraph(section["heading"], s["h2"]))
        for p in section.get("paragraphs", []):
            story.append(Paragraph(p, s["body"]))
        if section.get("bullets"):
            story.append(ListFlowable(
                [ListItem(Paragraph(b, s["list"]), leftIndent=14)
                 for b in section["bullets"]],
                bulletType="bullet", start="•", leftIndent=14,
            ))

    sig = (signature_block or DEFAULT_SIGNATURE_BLOCK).format(today=date.today().isoformat())
    story.append(Paragraph(sig, s["signoff"]))
    story.append(Paragraph(reservation_language or DEFAULT_RESERVATION, s["footer"]))

    doc.build(story)
    print(f"wrote {out_path}")


def main():
    ap = argparse.ArgumentParser(description="Build a regulator-policy PDF from a versioned template.")
    ap.add_argument("--regulator", required=True, help=f"Regulator code: one of {', '.join(REGULATOR_LABELS)}")
    ap.add_argument("--category",  required=True, help="policy_category_slug from compliance_policy_categories")
    ap.add_argument("--year",      required=True, type=int)
    ap.add_argument("--out",       required=True, type=Path)
    ap.add_argument("--signature-block", default=None)
    ap.add_argument("--reservation-language", default=None)
    args = ap.parse_args()

    if args.regulator not in REGULATOR_LABELS:
        sys.stderr.write(f"warning: unknown regulator code '{args.regulator}'. Using as-is.\n")

    build(args.regulator, args.category, args.year, args.out,
          signature_block=args.signature_block,
          reservation_language=args.reservation_language)


if __name__ == "__main__":
    main()
