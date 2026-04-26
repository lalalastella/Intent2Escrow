"""
FastAPI surface for Intent2Escrow.

Endpoints:
  GET  /api/health           — liveness
  POST /api/parse-deal       — text -> validated EscrowSpec + digest

CORS is wide-open (*) because this is a hackathon demo served from a static
frontend on a different origin (or just file://). For production this would
be locked to the deployed frontend domain.
"""
from __future__ import annotations

import logging
import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import ValidationError

from .parser import parse_deal
from .schemas import ParseDealRequest, ParseDealResponse

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("intent2escrow")

app = FastAPI(title="Intent2Escrow Backend", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health():
    return {
        "ok": True,
        "openai_key_present": bool(os.environ.get("OPENAI_API_KEY")),
    }


@app.post("/api/parse-deal", response_model=ParseDealResponse)
def post_parse_deal(req: ParseDealRequest):
    try:
        spec, canonical, digest = parse_deal(req.text)
    except ValidationError as e:
        first = e.errors()[0]
        log.warning("validation failed: %s", first)
        raise HTTPException(
            status_code=400,
            detail={
                "error": first["msg"],
                "field": ".".join(str(x) for x in first["loc"]),
            },
        )
    except ValueError as e:
        log.warning("parse failed: %s", e)
        raise HTTPException(status_code=400, detail={"error": str(e)})
    except Exception as e:
        log.exception("unexpected parser error")
        raise HTTPException(status_code=502, detail={"error": f"upstream error: {e}"})

    return ParseDealResponse(
        spec=spec,
        metadata_digest_hex=digest,
        canonical_json=canonical,
    )
