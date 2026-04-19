# Intent2Escrow

> Turn natural-language deal terms into verifiable on-chain settlement.

An AI-powered escrow dApp for the MSX Web3 Hackathon (April 2026). Users describe a deal in plain English; an LLM parses it into a structured spec; a Solidity contract on Base Sepolia holds funds until release conditions are met.

## Status

🚧 In active development. See [Intent2Escrow_Master_Plan.md](./Intent2Escrow_Master_Plan.md) for the full plan.

**Day 1 (Apr 19) — ✅ Done:**
- EscrowBook contract written with OpenZeppelin SafeERC20 + ReentrancyGuard
- 7 Foundry unit tests passing
- Deployed and source-verified on Base Sepolia

## Contract

- **EscrowBook**: [`0x4DE20B4eC770DadfD403383Eb819f202C1d1272d`](https://base-sepolia.blockscout.com/address/0x4DE20B4eC770DadfD403383Eb819f202C1d1272d)
- **Network**: Base Sepolia (Chain ID 84532)

## Why Web3 is essential here

Without on-chain escrow, this is a form builder. With it, two strangers can commit to a deal with enforceable terms, shared state, and no platform custody. The contract — not us — holds the money.

## Architecture (planned)

- Next.js + wagmi + viem frontend
- FastAPI backend for LLM parsing + IPFS pinning
- Solidity `EscrowBook` contract on Base Sepolia
- IPFS for deal metadata and evidence

## Run contract tests

```bash
cd contracts
forge test -vv
```

## License

MIT
