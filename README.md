## Starter for Ritual workshop on 23th June 2026

/hardhat -> Where we'll write the smart contract

/web -> Where the frontend lives.

## Privacy-preserving AI Bounty Judge

This fork implements the required commit-reveal bounty flow so answers are not
stored publicly during the submission phase. Participants first submit a
`bytes32` commitment, then reveal the answer and salt after submissions close.
Only answers that reveal against a valid commitment are eligible for Ritual AI
batch judging.

### Lifecycle

1. The bounty owner calls `createBounty(title, rubric, submissionDeadline, revealDeadline)` and funds the reward.
2. Before `submissionDeadline`, each participant calls `submitCommitment(bountyId, commitment)`.
3. The commitment is computed as:

   ```solidity
   keccak256(abi.encodePacked(answer, salt, msg.sender, bountyId))
   ```

4. After `submissionDeadline` and before `revealDeadline`, participants call `revealAnswer(bountyId, answer, salt)`.
5. The contract recomputes the commitment and stores only valid revealed answers in the eligible submissions list.
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

### Test plan

The Solidity tests in `hardhat/contracts/AIJudge.t.sol` cover:

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

In a bounty system, the bounty rules, reward amount, deadlines, participant
addresses, and final payout should be public so everyone can audit the process.
The actual answers should stay hidden during the submission phase so later
participants cannot copy or improve earlier work unfairly. Commitments are a
good public substitute because they prove a participant locked in an answer
without revealing it. AI should help compare submissions against the rubric,
summarize tradeoffs, and recommend a ranking when many answers need to be judged
consistently. A human bounty owner should still make the final payout decision
because AI output can be ambiguous, biased, or malformed. For higher-stakes
bounties, the system should preserve an audit trail showing what the AI judged
and why. Ritual's private execution is useful because it lets the AI evaluate
hidden submissions without exposing them to competitors before judging is
complete.

See `ARCHITECTURE.md` for the Ritual-native encrypted submission design note.
