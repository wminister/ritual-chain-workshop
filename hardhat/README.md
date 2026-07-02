# Hardhat

This folder contains the Solidity contract for the bounty judge.

The main contract is `contracts/AIJudge.sol`. I changed it from direct answer
submission to a commit-reveal flow:

1. participants submit a commitment before the submission deadline
2. they reveal the answer and salt during the reveal window
3. only valid reveals are eligible for judging
4. the owner judges all valid reveals in one Ritual AI batch
5. the owner finalizes one winner

The tests are in `contracts/AIJudge.t.sol`.

```shell
pnpm install
pnpm hardhat test
```

Deployment is handled by `ignition/modules/AIJudge.ts`. The Ritual deployment I
used for the homework is documented in the root `DEPLOYMENT.md`.
