# Intent2Escrow — Backend

FastAPI service that converts natural-language deal descriptions into validated `EscrowSpec` objects using OpenAI structured outputs.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Liveness check |
| `POST` | `/api/parse-deal` | Text → validated EscrowSpec + keccak256 digest |

## Setup

```bash
cd packages/backend
echo "OPENAI_API_KEY=sk-..." > .env   # fill in your key
pip install -r backend_requirements.txt
uvicorn app.main:app --port 8000 --reload
```

Requires Python 3.11+.

## Run tests

```bash
pytest test/test_schemas.py -v
```

These tests run without an API key (no LLM calls). For live LLM smoke tests:

```bash
OPENAI_API_KEY=sk-... python test/live_parse_smoke.py
```

## How parsing works

1. User text is sent to `gpt-4o-mini` with a strict JSON schema (`response_format=json_schema, strict=True`)
2. The model returns a `RawEscrowSpec` (shape-validated by the schema)
3. Pydantic re-validates all fields: address checksum, amount > 0, deadlines in future and ordered, token in allowlist
4. A canonical JSON is produced and keccak256-hashed — this digest becomes the `metadataCID` stored on-chain

The LLM never decides who the payer is. Payer identity comes solely from `msg.sender` at transaction time.
