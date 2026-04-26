"""
Tests for the validation layer.

We test the deterministic Pydantic + helper code without hitting OpenAI,
so this runs in CI / on a clean clone with no API key. The LLM golden
inputs in fixtures/ are exercised by a separate live test that we run
manually before submitting (see tests/live_parse_smoke.py).
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.parser import _amount_to_wei, _canonical_json, _digest, _to_unix
from app.schemas import EscrowSpec


def _future(seconds: int) -> int:
    return int((datetime.now(timezone.utc) + timedelta(seconds=seconds)).timestamp())


def _good_spec(**overrides) -> dict:
    base = dict(
        payer_hint="Alice",
        payee_hint="Bob",
        payee_address="0x70997970c51812dc3a010c7d01b50e0d17dc79c8",  # Anvil acct 1, lowercased
        token_symbol="mUSDC",
        amount_decimal="50",
        amount_wei="50000000",
        fund_deadline=_future(3600),
        release_deadline=_future(3 * 24 * 3600),
        evidence_required=True,
        description="logo delivery deal",
        warnings=[],
    )
    base.update(overrides)
    return base


# ---------- happy path ----------

def test_good_spec_validates_and_checksums_address():
    spec = EscrowSpec(**_good_spec())
    # eth_utils returns the EIP-55 checksum form
    assert spec.payee_address == "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"


def test_amount_to_wei_six_decimals():
    assert _amount_to_wei("50", 6) == "50000000"
    assert _amount_to_wei("50.5", 6) == "50500000"
    assert _amount_to_wei("0.000001", 6) == "1"


# ---------- rejections ----------

def test_rejects_zero_amount():
    with pytest.raises(ValidationError):
        EscrowSpec(**_good_spec(amount_decimal="0", amount_wei="0"))


def test_rejects_invalid_address():
    with pytest.raises(ValidationError):
        EscrowSpec(**_good_spec(payee_address="0xnope"))


def test_rejects_non_allowlisted_token():
    with pytest.raises(ValidationError):
        EscrowSpec(**_good_spec(token_symbol="USDT"))


def test_rejects_release_before_fund():
    fund = _future(3600)
    with pytest.raises(ValidationError) as e:
        EscrowSpec(**_good_spec(fund_deadline=fund, release_deadline=fund - 60))
    assert "release_deadline" in str(e.value)


def test_rejects_fund_in_past():
    with pytest.raises(ValidationError):
        EscrowSpec(**_good_spec(fund_deadline=int(datetime.now(timezone.utc).timestamp()) - 60))


def test_payee_address_can_be_null():
    spec = EscrowSpec(**_good_spec(payee_address=None))
    assert spec.payee_address is None


# ---------- canonical json + digest are deterministic ----------

def test_canonical_json_is_sorted_and_stable():
    a = _canonical_json({"b": 2, "a": 1})
    b = _canonical_json({"a": 1, "b": 2})
    assert a == b == '{"a":1,"b":2}'


def test_digest_is_deterministic_and_prefixed():
    d1 = _digest('{"a":1}')
    d2 = _digest('{"a":1}')
    assert d1 == d2
    assert d1.startswith("0x")
    assert len(d1) == 66  # 0x + 64 hex


# ---------- iso parsing ----------

def test_to_unix_handles_z_and_offset():
    a = _to_unix("2030-01-01T00:00:00Z")
    b = _to_unix("2030-01-01T00:00:00+00:00")
    assert a == b


# ---------- fixtures load ----------

FIXTURES = Path(__file__).parent / "fixtures"

def test_fixtures_directory_has_inputs():
    files = list(FIXTURES.glob("*.json"))
    assert len(files) >= 5, "expected at least 5 fixture inputs for live smoke test"
    for f in files:
        data = json.loads(f.read_text())
        assert "input" in data
        assert "expect" in data
