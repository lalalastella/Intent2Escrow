# EscrowBook — Contracts

Solidity contracts for Intent2Escrow, built with Foundry and OpenZeppelin.

## Contracts

| Contract | Description |
|----------|-------------|
| `src/EscrowBook.sol` | Main escrow state machine. Holds ERC-20 funds until payer releases or refund deadline passes. |
| `src/MockUSDC.sol` | Demo ERC-20 with 6 decimals and a public `mint()`. Testnet only. |

## Deployed (Base Sepolia)

| Contract | Address |
|----------|---------|
| EscrowBook | `0x4DE20B4eC770DadfD403383Eb819f202C1d1272d` |
| MockUSDC | `0x220BAc08b870EB6831F39c6E665FEfd156c5Bb38` |

## Run tests

```bash
forge test -vv
```

7 tests covering happy paths, access control, deadline enforcement, and input validation.

## Deploy

Set env vars first (`BASE_SEPOLIA_RPC_URL`, `PRIVATE_KEY`, `BASESCAN_API_KEY`), then:

```bash
# Deploy MockUSDC (testnet faucet token)
forge script script/DeployMockUSDC.s.sol:DeployMockUSDC \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

## State machine

```
Created → Funded → EvidenceSubmitted → Released
                └──────────────────→ Refunded (past releaseDeadline)
```

`evidenceRequired = false` allows direct `Funded → Released`.
