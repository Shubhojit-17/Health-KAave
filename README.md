# Health KAave

[![Hackathon](https://img.shields.io/badge/Hackathon-Hook_the_Future-purple.svg)](https://github.com/Shubhojit-17/Health-KAave)
[![Uniswap V4](https://img.shields.io/badge/Uniswap-V4-ff007a.svg)](https://uniswap.org/)
[![Network](https://img.shields.io/badge/Network-X_Layer_Testnet-black.svg)](https://www.okx.com/explorer/x-layer-test)
[![Foundry](https://img.shields.io/badge/Built_with-Foundry-blue.svg)](https://book.getfoundry.sh/)

> **A Uniswap V4 hook on X Layer that dynamically prices swap fees based on a user's real-time Aave Health Factor.**
> By connecting X Layer's lending and swapping ecosystems, Health KAave shifts AMM fee pricing from volatility to creditworthiness.

## Overview

Health KAave introduces a new DeFi primitive: **credit-based fees**. The hook reads a user's live risk metrics from Aave v3 and adjusts the AMM fee during swaps. That creates a built-in liquidity flywheel on X Layer, where healthier borrowers can execute swaps at a lower fee.

## How It Works

The core logic runs inside the `beforeSwap` callback. The hook decodes the user's address from `hookData`, calls Aave's `getUserAccountData()`, and adjusts the pool fee dynamically.

| Aave Health Factor (HF) | User Profile | Swap Fee Applied | Impact |
| :-- | :-- | :-- | :-- |
| `HF >= 2.0` | Strong Borrower | `0.01%` | Heavily discounted rate; incentivizes volume |
| `HF 1.5 - 2.0` | Moderate Debt | `0.30%` | Standard pool fee |
| `No Debt` | Standard User | `0.30%` | Standard pool fee with graceful fallback |
| `HF < 1.5` | Underwater | `0.50%` | Premium fee; acts as a soft circuit breaker |

The hook also includes a `try/catch` fallback so that if the Aave call fails, or if the user has no debt, the swap continues at the standard `0.30%` fee instead of reverting.

## Deployed Contracts

This project has been deployed and verified on X Layer Testnet (Chain ID `1952`).

| Contract | Address |
| :-- | :-- |
| Health KAave Hook | [0x41c74E079C9000cbb4878fA58934A957D00E0080](https://www.okx.com/explorer/x-layer-test/address/0x41c74E079C9000cbb4878fA58934A957D00E0080) |
| V4 PoolManager | `0x2e09c1117542076dA6925C6275793b1e5d4132EA` |
| V4 PositionManager | `0x0fE4C5971c2F83F0647eC927d8CD8D25129425B0` |

## Repository Structure

```text
.
├── src/
│   ├── AaveHealthHook.sol
│   ├── Counter.sol
│   └── interfaces/
├── test/
│   ├── AaveHealthHook.t.sol
│   ├── Counter.t.sol
│   └── utils/
├── script/
│   ├── DeployHook.s.sol
│   ├── InitializePool.s.sol
│   └── ...
├── lib/
│   ├── forge-std/
│   ├── hookmate/
│   └── uniswap-hooks/
├── foundry.toml
├── remappings.txt
└── README.md
```

## Getting Started

### Prerequisites

Install [Foundry](https://book.getfoundry.sh/getting-started/installation) if you do not already have it.

### Clone the repository

```bash
git clone https://github.com/Shubhojit-17/Health-KAave.git
cd Health-KAave
```

### Install dependencies

```bash
forge install
```

### Build and test

```bash
forge build
forge test
```

## Tests

The current suite includes regression coverage for `msg.sender` and `hookData` contexts. All 7 tests in `AaveHealthHook.t.sol` pass.

## Acknowledgments

Built for the Hook the Future Hackathon by OKX and the Uniswap Foundation.

## Socials

- [@XLayerOfficial](https://x.com/XLayerOfficial)
- [@Uniswap](https://x.com/Uniswap)
- [@flapdotsh](https://x.com/flapdotsh)