## Starter for Ritual workshop on June 23, 2026

/hardhat -> Where we'll write the smart contract

/web -> Where the frontend lives.

## Privacy-preserving AI Bounty Judge

For this homework I changed the bounty flow so answers are not posted on-chain
right away. Instead of submitting the answer directly, a participant submits a
`bytes32` commitment first. After the submission deadline passes, they reveal the
answer and salt, and the contract checks that the reveal matches the original
commitment. Only valid reveals are sent to Ritual AI for judging.

### Lifecycle

1. The bounty owner calls `createBounty(title, rubric, submissionDeadline, revealDeadline)` and funds the reward.
2. Before `submissionDeadline`, each participant calls `submitCommitment(bountyId, commitment)`.
3. The commitment is computed as:

   ```solidity
   keccak256(abi.encodePacked(answer, salt, msg.sender, bountyId))
   ```

4. After `submissionDeadline` and before `revealDeadline`, participants call `revealAnswer(bountyId, answer, salt)`.
5. The contract recomputes the hash and only stores the answer if the reveal is valid.
6. After `revealDeadline`, the owner calls `judgeAll(bountyId, llmInput)` once with a batch prompt containing all valid reveals.
7. After judging completes, the owner calls `finalizeWinner(bountyId, winnerIndex)` and the contract pays exactly one winner.

### Contract rules

- A participant can submit only one commitment per bounty.
- Commitments are accepted only before the submission deadline.
- Reveals are accepted only during the reveal window.
- Reveals must match `answer`, `salt`, `msg.sender`, and `bountyId`.
- Unrevealed or invalid submissions are not included in `getSubmission`.
- Judging can run only after the reveal deadline.
- Finalization can run only after judging and only once.
- `winnerIndex` must point to a valid revealed submission.

### Tests

I added Solidity tests in `hardhat/contracts/AIJudge.t.sol` for the cases I
thought were most important:

- valid commitment followed by valid reveal
- reveal with the wrong salt
- copied commitment revealed by a different sender
- reveal before the reveal window
- reveal after the reveal deadline
- duplicate commitment from the same participant
- unrevealed commitments excluded from eligible submissions
- `judgeAll` blocked while the reveal window is still open

Run the tests from the Hardhat project:

```shell
cd hardhat
pnpm install
pnpm hardhat test solidity
```

### Reflection

In a bounty system, I think the rules, reward, deadlines, participant addresses,
and final payout should be public because people need to audit what happened.
The answers themselves should stay hidden while submissions are still open, since
otherwise people can copy earlier ideas and improve on them. A commitment is a
good middle ground because it proves someone locked in an answer without showing
the answer yet. AI is useful for comparing all valid submissions against the
rubric and giving the owner a ranking or recommendation. I would still keep a
human in charge of the final payout, because AI can misunderstand context or
produce an unclear result. For bigger bounties, I would also want the judging
result and the final revealed answer bundle to be easy to review later. Ritual's
private execution is interesting here because it could let the AI judge hidden
submissions without exposing them to other participants first.

See `ARCHITECTURE.md` for the Ritual-native encrypted submission design note.
