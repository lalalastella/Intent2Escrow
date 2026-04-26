"""
Pydantic schemas for Intent2Escrow.

EscrowSpec is the structured representation we extract from natural language.
It mirrors the contract's `EscrowParams` struct one-to-one so the frontend can
hand it directly to wagmi/viem with minimal transformation.

Validation philosophy: the LLM may hallucinate. Every field gets re-checked
here with strict types and cross-field rules. Validation failure -> HTTP 400,
never auto-fix. The user edits and retries.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import List, Optional

from eth_utils import is_address, to_checksum_address
from pydantic import BaseModel, Field, field_validator, model_validator


# ---------- Raw LLM output (what the model returns before validation) ----------

class RawEscrowSpec(BaseModel):
    """Shape we ask the LLM for. Matches the json_schema in parser.py."""

    payer_hint: Optional[str] = None
    payee_hint: Optional[str] = None
    payee_address: Optional[str] = None  # checksum-validated downstream
    token_symbol: str = "mUSDC"
    amount: str = "0"  # decimal string
    fund_deadline: Optional[str] = None  # ISO-8601 UTC
    release_deadline: Optional[str] = None
    evidence_required: bool = False
    description: str = ""
    warnings: List[str] = Field(default_factory=list)


# ---------- Validated output (what we hand back to the frontend) ----------

# Allowlist for MVP. The frontend should NOT trust arbitrary tokens; the
# contract trusts whatever the payer signs, but our UI gates the choice.
TOKEN_ALLOWLIST = {"mUSDC"}


class EscrowSpec(BaseModel):
    """Validated spec, ready to be passed to the contract via the frontend."""

    payer_hint: Optional[str] = None
    payee_hint: Optional[str] = None
    payee_address: Optional[str] = None  # checksummed if present
    token_symbol: str
    amount_decimal: str  # human-readable, e.g. "50.5"
    amount_wei: str      # uint256 string for the contract (mUSDC has 6 decimals)
    fund_deadline: int   # unix seconds, must be > now
    release_deadline: int
    evidence_required: bool
    description: str
    warnings: List[str] = Field(default_factory=list)

    @field_validator("payee_address")
    @classmethod
    def _checksum_address(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        if not is_address(v):
            raise ValueError(f"payee_address is not a valid address: {v}")
        return to_checksum_address(v)

    @field_validator("token_symbol")
    @classmethod
    def _allowlist(cls, v: str) -> str:
        if v not in TOKEN_ALLOWLIST:
            raise ValueError(
                f"token_symbol {v!r} not in MVP allowlist {sorted(TOKEN_ALLOWLIST)}"
            )
        return v

    @model_validator(mode="after")
    def _cross_field(self) -> "EscrowSpec":
        # amount > 0
        try:
            amt = Decimal(self.amount_decimal)
        except (InvalidOperation, TypeError):
            raise ValueError(f"amount_decimal not numeric: {self.amount_decimal!r}")
        if amt <= 0:
            raise ValueError("amount must be > 0")

        # deadlines in future, fund < release
        now = int(datetime.now(timezone.utc).timestamp())
        if self.fund_deadline <= now:
            raise ValueError("fund_deadline is in the past")
        if self.release_deadline <= self.fund_deadline:
            raise ValueError("release_deadline must be strictly after fund_deadline")

        return self


# ---------- API request/response shapes ----------

class ParseDealRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class ParseDealResponse(BaseModel):
    spec: EscrowSpec
    metadata_digest_hex: str  # keccak256(canonical_json), 0x-prefixed
    canonical_json: str       # exactly what was hashed; frontend can pin if it wants


class ParseDealError(BaseModel):
    error: str
    field: Optional[str] = None
    raw_llm_output: Optional[dict] = None
