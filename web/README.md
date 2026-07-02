# Web app

This is the Next.js frontend for the Ritual bounty judge demo.

I updated the UI to match the commit-reveal contract:

1. the owner creates a bounty with a submission deadline and a reveal deadline
2. participants enter an answer and salt phrase
3. during the submission phase, the app submits only the commitment hash
4. during the reveal phase, the same answer and salt phrase are revealed
5. after the reveal deadline, the owner sends all valid reveals to Ritual AI in one batch
6. the owner picks and finalizes the winner

The app computes the commitment with the same formula as the contract:

```solidity
keccak256(abi.encodePacked(answer, salt, msg.sender, bountyId))
```

## Setup

Copy the example env file and fill in the deployed contract address:

```shell
cp .env.example .env.local
```

Useful variables:

- `NEXT_PUBLIC_CONTRACT_ADDRESS`
- `NEXT_PUBLIC_RITUAL_RPC_URL`
- `NEXT_PUBLIC_RITUAL_CHAIN_ID`
- `NEXT_PUBLIC_RITUAL_EXECUTOR_ADDRESS`
- `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`

Run locally:

```shell
pnpm install
pnpm dev
```

The dashboard should be available at `http://localhost:3000`.
