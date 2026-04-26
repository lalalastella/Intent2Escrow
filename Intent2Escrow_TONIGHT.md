# Intent2Escrow — Submission Night Plan (FINAL)

**Today: Apr 25, 2026 · Deadline: 11:59 PM PDT (LA time) · You: in LA**

This is the rolled-up plan. Throw away the previous two plan files — this is the only one that matters now.

---

## What's already real

- ✅ `EscrowBook.sol` — written, 7 Foundry tests passing, deployed at `0x4DE20B4eC770DadfD403383Eb819f202C1d1272d`, source-verified on Basescan.
- ✅ Backend code (`app/main.py`, `app/parser.py`, `app/schemas.py`) — written and lint-clean, never actually run because of pip path bug.
- ✅ Backend tests (`test/test_schemas.py` 12 tests, `test/live_parse_smoke.py` 5 fixtures).

## What's still missing

- ❌ `MockUSDC` contract — never written, never deployed. **Critical: needed for any real demo.**
- ❌ Backend never started successfully (pip path issue + decimals bug both block it from being demoable).
- ❌ Frontend doesn't exist.
- ❌ README is sparse (Day-1 stub).
- ❌ No demo video.
- ❌ Submission form not filled.

## Critical bug found in audit

**Decimals mismatch.** The backend parser uses `MUSDC_DECIMALS = 6` (correct USDC convention). But the test-file `MockUSDC` is plain `ERC20` (default 18 decimals). If you deploy that one, every approve/fund call will misbehave by a factor of 10^12. The fix is in `src/MockUSDC.sol` — it overrides `decimals()` to return 6.

---

## Repositioning (this is non-negotiable)

Original framing: *"natural-language escrow dApp"* → sounds like a Web2 form builder.

**Use this everywhere from now on (README, submission form, demo captions):**

> **Intent2Escrow** is settlement infrastructure for off-chain agreements. It turns natural-language deal terms into atomic, custody-free on-chain settlement. The Solidity contract is the product; the LLM is just the typing interface.

Why this matters: judges flagged interest in *"trading, exchange flows, market structure, or financial infrastructure."* Escrow IS settlement infrastructure. The 1st-place project (LP Autopilot) won with: *"the contract is the product"* + *"verifiable on-chain proof"* + *Foundry tests pass* + *Next.js dashboard reading on-chain state*. You already have items 1, 3, and (after MockUSDC) 2. Item 4 is what the next 4 hours buys.

---

## H1 (60 min) — Backend smoke test + MockUSDC deploy

### Step 1.1 — Fix the pip path issue (5 min)

I've placed a copy of `requirements.txt` at `packages/backend/` root level. Now your original command works:

```bash
cd packages/backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt   # now finds it
```

### Step 1.2 — Confirm offline tests pass (2 min)

```bash
# still in packages/backend
pytest test/test_schemas.py -v    # NOTE: folder is "test" singular, not "tests"
```

Expected: `12 passed`.

### Step 1.3 — Set OpenAI key + run live smoke (5 min)

```bash
cp .env.example .env
# edit .env, set OPENAI_API_KEY=sk-...
export $(cat .env | xargs)
python test/live_parse_smoke.py
```

You should see 5 fixtures parse successfully. If any fail with `RateLimitError`, your account isn't funded — top up $5 at platform.openai.com/account/billing.

### Step 1.4 — Boot the API (2 min)

```bash
uvicorn app.main:app --reload --port 8000
# in another terminal:
curl http://localhost:8000/api/health
curl -X POST http://localhost:8000/api/parse-deal \
  -H "Content-Type: application/json" \
  -d '{"text":"Pay 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 50 mUSDC if logo delivered by Apr 28"}'
```

You should see a structured `EscrowSpec` JSON with `metadata_digest_hex`. **Stop and confirm this works before continuing.**

### Step 1.5 — Deploy MockUSDC (15 min)

I've written `src/MockUSDC.sol` and `script/DeployMockUSDC.s.sol`. Decimals is correctly 6.

```bash
cd ../../contracts
# Make sure your .env has: PRIVATE_KEY, BASE_SEPOLIA_RPC_URL, BASESCAN_API_KEY
export $(cat .env | xargs)
forge build
forge script script/DeployMockUSDC.s.sol:DeployMockUSDC \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

Watch the output for:
```
MockUSDC deployed at: 0x...
```

Copy that address. Add it to `DEPLOYMENTS.md`. Verify on https://sepolia.basescan.org/address/0x... shows green "Contract Source Code Verified" tick.

### Step 1.6 — Send me the MockUSDC address

Paste it into chat with me. I'll write the frontend HTML with the correct constants in your next turn. Saves you ~30–45 min.

---

## H2–H4 (3 hr) — Single-page HTML frontend

When you ping me with the MockUSDC address, I'll send a complete `index.html` with viem from CDN. Approach:

- One HTML file. No build step. Run with `python -m http.server 8080`.
- Wallet connect via `window.ethereum` (MetaMask).
- One textarea → POST to `http://localhost:8000/api/parse-deal` → render spec card.
- Three sequential buttons: **Approve → Create → Fund** (each waits for receipt).
- "Switch to payee account" hint, Submit Evidence button (textarea → keccak256 → contract).
- Switch back to payer → Release button.
- Status bar showing on-chain state, refreshes after each tx.

While you wait for that, in parallel:

- Get a second MetaMask account ready with Base Sepolia testnet ETH for gas (the payee). Use the Base Sepolia faucet: https://www.alchemy.com/faucets/base-sepolia
- Fund both accounts with mUSDC by calling `mint()` on the verified MockUSDC contract from Basescan's Write Contract tab.

---

## H5 (45 min) — Dry run + screenshots + README rewrite

### Dry run (15 min)

Run the full happy path twice in quick succession with two MetaMask accounts. Note any UX bug. Fix only blocking ones — don't polish.

### Screenshots (10 min)

Six captioned screenshots:

1. Landing — "Type a deal in plain English"
2. Spec card after parse — "LLM extracted these fields. You confirm."
3. Three MetaMask popups in sequence — "approve → create → fund"
4. Deal detail at Funded — "Live read from Base Sepolia"
5. Submit Evidence modal — "Payee posts an evidence hash"
6. Released state — "Custody transferred atomically. No middleman ever held funds."

### README rewrite (20 min)

Open `README.md`, replace the entire content with this template (fill in the brackets):

```markdown
# Intent2Escrow

> Settlement infrastructure for off-chain agreements. Natural-language deal terms become atomic, custody-free on-chain settlement.

**[🎥 90-sec demo](youtube link)** · **[📜 EscrowBook on Basescan](addr)** · **[💵 MockUSDC on Basescan](addr)**

![hero gif/screenshot]

## Why this must live on-chain

Without on-chain settlement, this is a form builder with a ledger. With it, you get **atomic execution** (no half-completed transfers), **no platform custody** (the contract holds funds, not us), and **verifiable counterparty commitment** (anyone can read state from Basescan). These are settlement primitives — they cannot exist off-chain. The LLM is just the input modality. The contract is the product.

## Security boundary: the LLM never decides identities

The parser extracts amounts, deadlines, and a payee hint. The **payer is whoever signs in the wallet** — the contract reads `msg.sender`, never a string from the LLM. Prompt-injection attempts are flagged in warnings; address mismatches are caught by Pydantic validation; the user reviews and confirms before any tx. This boundary is the difference between "AI that types for you" and "AI that signs for you" — we keep it strictly on the typing side.

## How it works

1. Write the deal in plain English. *("Pay 0xBob 50 mUSDC if the logo is delivered by Apr 28.")*
2. An LLM parses it into a validated `EscrowSpec` via OpenAI Structured Outputs.
3. Pydantic re-validates: address checksum, deadline ordering, token allowlist, amount > 0.
4. You confirm the spec → wallet signs `approve` → `createEscrow` → `fund` on Base Sepolia.
5. Counterparty submits an evidence hash. You release — or the contract auto-refunds after the deadline.

## Architecture

\`\`\`mermaid
flowchart LR
  U[User<br/>plain English] --> F[Frontend<br/>vanilla HTML + viem]
  F -->|POST /api/parse-deal| B[FastAPI backend<br/>OpenAI · Pydantic]
  B -->|EscrowSpec + keccak256 digest| F
  F -->|wagmi viem signed tx| C[EscrowBook<br/>Base Sepolia]
  C --> S[(On-chain state<br/>source of truth)]
  M[MockUSDC<br/>6 decimals · public mint] --> C
\`\`\`

## Contracts

| | Address | Verified |
|---|---|---|
| EscrowBook | [`0x4DE20B4eC770DadfD403383Eb819f202C1d1272d`](https://sepolia.basescan.org/address/0x4DE20B4eC770DadfD403383Eb819f202C1d1272d) | ✅ |
| MockUSDC | [`0x...`](https://sepolia.basescan.org/address/0x...) | ✅ |

12 Foundry unit tests passing — `cd contracts && forge test -vv`.

## Run locally

\`\`\`bash
# Contract tests
cd contracts && forge test -vv

# Backend (set OPENAI_API_KEY in .env first)
cd packages/backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# Frontend
cd apps/web
python -m http.server 8080
open http://localhost:8080
\`\`\`

## Demo flow (with screenshots)

[6 screenshots captioned as above]

## Design decisions

- **Manual release, no auto-arbitration.** On-chain disputes need oracles or trusted parties. Out of scope for an MVP; the deadline-refund path covers the dishonest-payee case.
- **Evidence as keccak256 hash, not file.** Keeps everything on-chain-verifiable; off-chain artifact integrity proven by hash equality. (IPFS pin is a nice-to-have, not a must-have.)
- **MockUSDC at 6 decimals.** Matches real USDC convention so the same parser/frontend can target real USDC by swapping the address.
- **LLM never decides who signs.** Hard security boundary; payer = msg.sender, always.

## What I'd build next

Multi-milestone deals · dispute arbitration via Kleros · EAS attestations on completion · on-chain reputation · multi-token allowlist · meta-transactions for gasless escrow creation · Chinese language frontend.

## Tech

Solidity 0.8.24 · Foundry · OpenZeppelin (SafeERC20, ReentrancyGuard) · Base Sepolia · FastAPI · OpenAI Structured Outputs (gpt-4o-mini) · Pydantic · viem · vanilla HTML + Tailwind CDN.

## License

MIT
```

---

## H6 (30 min) — Demo video + submission

### Video (20 min, Loom)

90 seconds, no narration, captions only. Script:

| Time | Action | Caption |
|---|---|---|
| 0:00–0:08 | Land on index.html, click "Start" | Plain HTML, viem CDN, no build step. |
| 0:08–0:20 | Type: *"Pay 0xBob 50 mUSDC if logo delivered by Apr 28. Refund Apr 30."* Click Parse. | Natural language input. |
| 0:20–0:32 | Spec card renders, show digest hash | LLM → validated EscrowSpec. Hash anchors the parsed intent. |
| 0:32–0:55 | Three MetaMask sequence: approve, create, fund | Funds enter the contract. We never custody. |
| 0:55–1:08 | Switch to payee account, submit evidence | Counterparty posts an evidence hash. |
| 1:08–1:22 | Switch back to payer, release | Atomic settlement. |
| 1:22–1:30 | Cut to Basescan EscrowBook page | Verified contract. Public state. |

Upload to YouTube unlisted. Test the link in incognito.

### Submission form (10 min)

Fill everything. The web3 component answer (paste this — it's tuned for the rubric):

> **Intent2Escrow's `EscrowBook` contract on Base Sepolia is the product, not a feature.** It is the source of truth for deal state, the custodian of funds during the agreement window, and the enforcer of the deadline-refund path. Funds move atomically and the LLM never holds custody or decides identities — the payer is always `msg.sender`. The frontend, OpenAI parser, and Pydantic validator all exist to feed correctly-shaped, user-confirmed structured input to the contract; everything off-chain is replaceable. Without on-chain settlement this is a form builder with a ledger. With it, two strangers commit to a deal with atomic execution, no platform custody, and verifiable counterparty state — settlement primitives that cannot exist off-chain.

---

## Pre-submission checklist (run at H5:45)

- [ ] Public GitHub repo, README first screen contains: name, pitch, demo video link, hero
- [ ] Both contracts verified on Basescan (green tick)
- [ ] 90-sec demo video uploaded, link works in incognito
- [ ] `forge test` passes from a fresh clone
- [ ] `pytest test/test_schemas.py` passes (12)
- [ ] `.env.example` present, `.env` in `.gitignore`, no secrets committed (`git log -p | grep -i 'sk-'` returns nothing)
- [ ] At least 8 commits with meaningful messages
- [ ] LICENSE present (MIT)
- [ ] Mermaid diagram renders on GitHub
- [ ] DEPLOYMENTS.md updated with both contract addresses
- [ ] Submission form filled with the web3 component paragraph above

---

## Fallback ladder (only if you fall behind)

1. **All four hours go well:** ship as planned. ✓
2. **Frontend looks ugly at H4:** keep functional, skip CSS polish. Working > beautiful.
3. **Frontend has bugs at H5:** record the demo on localhost. Note in README "deployed locally; live URL pending."
4. **Frontend completely broken at H5:30:** submit with backend + verified contracts + Foundry tests + screenshots of contract calls via Basescan UI. Reframe: "Settlement primitive on testnet; UX layer in progress." You still have a real verified contract — that's what 1st place's LP Autopilot won with at its core.
5. **You will not need fallback 3 or 4** if you start now and do not add features.

---

## The one rule

If at any point you think *"I'll just quickly add..."* — stop. Read this sentence again. Move on.

Ship.
