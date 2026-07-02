# Architecture note

## What I implemented

The contract uses a commit-reveal pattern. During the submission phase, the
chain only stores a `bytes32` commitment. The commitment is made from the answer,
a private salt, `msg.sender`, and `bountyId`.

```solidity
keccak256(abi.encodePacked(answer, salt, msg.sender, bountyId))
```

I included `msg.sender` and `bountyId` so a different wallet cannot just copy
someone's commitment and reveal the same answer for another bounty. The plaintext
answer only appears on-chain during the reveal phase. That still means answers
become public before `judgeAll`, but it fixes the main copying problem during
the submission window.

The contract only adds an answer to the judging list after the reveal checks
pass. If someone never reveals, or reveals with the wrong salt, their answer is
not eligible.

## Ritual-native version

A more Ritual-native version could keep answers hidden until the actual judging
step. My design for that version would be:

- participants encrypt their answers off-chain
- encrypted answers are uploaded to IPFS, object storage, or another off-chain store
- the contract stores references and hashes, not plaintext answers
- a Ritual TEE executor decrypts the batch privately
- the LLM receives all submissions together in one request
- after judging, the winner and a final answer bundle can be published

The on-chain data would be things like:

- `encryptedAnswersRef`
- `encryptedAnswersHash`, a content hash committing to the encrypted batch
- per-participant commitment or receipt hashes
- bounty deadlines, owner, reward, and final judging status

Plaintext answers would only exist on the participant's machine before upload
and inside the TEE during judging. They would not be stored in public contract
storage. The important part is that the LLM should judge the submissions as a
batch, because the point is to compare answers against each other and the rubric.

The final result could look something like this:

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

The contract could store `revealedAnswersRef` and `revealedAnswersHash` instead
of storing all plaintext answers directly. That keeps gas costs lower and still
lets people verify that the final published bundle matches what was committed.
The AI can recommend a winner, but I would still have the bounty owner finalize
the payout.

## Tradeoff

Commit-reveal is simpler and works on any EVM chain. The downside is that
answers become public during the reveal window. The Ritual-native encrypted
version is more complicated because it needs encrypted storage and private
execution, but it gives better privacy because participants do not see each
other's answers before the judging step.
