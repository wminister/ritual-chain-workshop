# Architecture note: commit-reveal vs Ritual-native privacy

## Required track: commit-reveal

The implemented contract uses a standard EVM commit-reveal design. During the
submission phase, the chain stores only `bytes32 commitment` values. A
participant computes the commitment from the answer, a private salt,
`msg.sender`, and `bountyId`, which prevents another address from copying the
commitment and revealing the same plaintext later.

Plaintext answers first appear on-chain during the reveal phase. This is enough
to stop copying during submission, but revealed answers become public before the
owner calls `judgeAll`. The contract therefore enforces that only revealed,
verified answers are included in the eligible submission list.

## Advanced track: Ritual-native hidden submissions

A more Ritual-native version would keep plaintext answers hidden until the AI
judging step itself. Participants would encrypt answers off-chain for a Ritual
TEE executor or a Ritual-backed private input/key flow. The contract would store
only metadata such as:

- `encryptedAnswersRef`, for example an IPFS, object storage, or encrypted blob reference
- `encryptedAnswersHash`, a content hash committing to the encrypted batch
- per-participant commitment or receipt hashes
- bounty deadlines, owner, reward, and final judging status

Plaintext answers would exist only on the participant machine before upload and
inside the TEE during judging. They would not be stored in public contract
storage during submission or reveal. The LLM should receive one batch containing
all decrypted answers and the rubric, so it can compare submissions directly and
avoid one LLM call per answer.

After judging, the TEE workflow can publish a final output bundle:

```json
{
  "winnerIndex": 2,
  "ranking": [
    {
      "index": 2,
      "score": 94,
      "reason": "Best satisfies the rubric."
    }
  ],
  "revealedAnswersRef": "ipfs://...",
  "revealedAnswersHash": "0x...",
  "summary": "Submission 2 is the strongest answer."
}
```

The contract should store `revealedAnswersRef` and `revealedAnswersHash` rather
than every plaintext answer, unless the bounty intentionally accepts the gas
cost of full on-chain storage. The human owner still finalizes the payout after
reviewing the AI recommendation. This preserves a human-in-the-loop decision
while using Ritual's TEE-backed execution for private AI evaluation.

## Comparison

Commit-reveal is simple, cheap, and works on any EVM chain. Its main limitation
is that answers become public during the reveal window, before AI judging
finishes. A Ritual-native encrypted design is more complex because it needs key
management, encrypted storage, and a trusted execution flow, but it gives better
privacy because plaintext is visible only to the participant and the private
executor until the final result is published.
