"""
Manual live smoke test. Run before submission to confirm the LLM behaves
on every fixture.

Usage:
    cd packages/backend
    OPENAI_API_KEY=sk-... python tests/live_parse_smoke.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.parser import parse_deal  # noqa: E402

FIXTURES = Path(__file__).parent / "fixtures"


def main() -> int:
    if not os.environ.get("OPENAI_API_KEY"):
        print("OPENAI_API_KEY not set — aborting live smoke.")
        return 1

    failed = 0
    for f in sorted(FIXTURES.glob("*.json")):
        case = json.loads(f.read_text())
        print(f"\n=== {case['name']} ===")
        print(f"input: {case['input']}")
        try:
            spec, _, digest = parse_deal(case["input"])
        except Exception as e:
            print(f"  PARSE FAILED: {e}")
            failed += 1
            continue

        print(f"  payee_address    : {spec.payee_address}")
        print(f"  amount_decimal   : {spec.amount_decimal}")
        print(f"  amount_wei       : {spec.amount_wei}")
        print(f"  fund_deadline    : {spec.fund_deadline}")
        print(f"  release_deadline : {spec.release_deadline}")
        print(f"  evidence_required: {spec.evidence_required}")
        print(f"  description      : {spec.description}")
        print(f"  warnings         : {spec.warnings}")
        print(f"  digest           : {digest}")

    print(f"\n{failed} failure(s).")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
