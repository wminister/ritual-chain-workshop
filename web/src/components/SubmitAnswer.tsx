"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { encodePacked, keccak256, toBytes } from "viem";
import { useNow } from "@/hooks/useNow";
import aiJudgeAbi from "@/abi/AIJudge";
import { contractAddress } from "@/config/contract";
import { ritualChain } from "@/config/wagmi";
import { canCommit, canReveal, type Bounty } from "@/lib/bounty";
import { useWriteTx } from "@/hooks/useWriteTx";
import {
  Card,
  CardHeader,
  CardBody,
  Field,
  Textarea,
  Button,
  TxStatus,
} from "@/components/ui";

const explorerBase = ritualChain.blockExplorers?.default.url;

export function SubmitAnswer({
  bountyId,
  bounty,
  onSubmitted,
}: {
  bountyId: bigint;
  bounty: Bounty;
  onSubmitted: () => void;
}) {
  const { isConnected } = useAccount();
  const { address } = useAccount();
  const [answer, setAnswer] = useState("");
  const [saltPhrase, setSaltPhrase] = useState("");
  const now = useNow();
  const tx = useWriteTx(() => {
    onSubmitted();
  });

  const commitOpen = canCommit(bounty, now / 1000);
  const revealOpen = canReveal(bounty, now / 1000);

  // No participant action is available outside the commit/reveal windows.
  if (!commitOpen && !revealOpen) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!answer.trim() || !saltPhrase.trim() || !contractAddress || !address) return;
    const salt = keccak256(toBytes(saltPhrase.trim()));
    try {
      if (commitOpen) {
        const commitment = keccak256(
          encodePacked(
            ["string", "bytes32", "address", "uint256"],
            [answer.trim(), salt, address, bountyId],
          ),
        );

        await tx.run({
          address: contractAddress,
          abi: aiJudgeAbi,
          functionName: "submitCommitment",
          args: [bountyId, commitment],
          chainId: ritualChain.id,
        });
        return;
      }

      await tx.run({
        address: contractAddress,
        abi: aiJudgeAbi,
        functionName: "revealAnswer",
        args: [bountyId, answer.trim(), salt],
        chainId: ritualChain.id,
      });
    } catch {
      /* surfaced via tx.state */
    }
  }

  return (
    <Card>
      <CardHeader
        title={commitOpen ? "Submit a commitment" : "Reveal your answer"}
        subtitle={
          commitOpen
            ? "Only the hash is stored during the submission phase."
            : "Reveal the exact answer and salt phrase used for your commitment."
        }
      />
      <CardBody>
        <form onSubmit={handleSubmit} className="space-y-3">
          <Field label="Your answer">
            <Textarea
              value={answer}
              onChange={(e) => setAnswer(e.target.value)}
              rows={5}
              placeholder={
                commitOpen
                  ? "Write your private answer. Save it locally for reveal."
                  : "Paste the exact answer you committed."
              }
            />
          </Field>
          <Field label="Salt phrase" hint="Use the same private phrase for commit and reveal.">
            <Textarea
              value={saltPhrase}
              onChange={(e) => setSaltPhrase(e.target.value)}
              rows={2}
              placeholder="Private random phrase"
            />
          </Field>
          <Button
            type="submit"
            disabled={!isConnected || !answer.trim() || !saltPhrase.trim() || tx.isBusy}
            className="w-full"
          >
            {tx.isBusy
              ? commitOpen
                ? "Committing…"
                : "Revealing…"
              : commitOpen
                ? "Submit commitment"
                : "Reveal answer"}
          </Button>
          {!isConnected && (
            <p className="text-xs text-zinc-500">
              Connect your wallet to submit.
            </p>
          )}
          <TxStatus
            state={tx.state}
            error={tx.error}
            hash={tx.hash}
            explorerBase={explorerBase}
          />
        </form>
      </CardBody>
    </Card>
  );
}
