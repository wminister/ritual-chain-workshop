// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AIJudge} from "./AIJudge.sol";

contract AIJudgeTest is Test {
    AIJudge private judge;

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    function setUp() public {
        judge = new AIJudge();
        vm.deal(address(this), 10 ether);
        vm.warp(1_000);
    }

    function test_SubmitCommitmentAndRevealAnswer() public {
        uint256 bountyId = _createBounty();
        string memory answer = "Build the commit-reveal flow.";
        bytes32 salt = keccak256("alice salt");
        bytes32 commitment = _commit(answer, salt, alice, bountyId);

        vm.prank(alice);
        judge.submitCommitment(bountyId, commitment);

        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        judge.revealAnswer(bountyId, answer, salt);

        (address submitter, string memory revealedAnswer) = judge.getSubmission(
            bountyId,
            0
        );

        assertEq(submitter, alice);
        assertEq(revealedAnswer, answer);

        (, bool revealed, uint256 revealedIndex) = judge.getCommitment(
            bountyId,
            alice
        );

        assertTrue(revealed);
        assertEq(revealedIndex, 0);
    }

    function test_RevealWithWrongSaltFails() public {
        uint256 bountyId = _createBounty();
        string memory answer = "Secret answer";
        bytes32 salt = keccak256("real salt");
        bytes32 wrongSalt = keccak256("wrong salt");

        vm.prank(alice);
        judge.submitCommitment(bountyId, _commit(answer, salt, alice, bountyId));

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(bytes("invalid reveal"));
        vm.prank(alice);
        judge.revealAnswer(bountyId, answer, wrongSalt);
    }

    function test_CopiedCommitmentCannotBeRevealedByAnotherSender() public {
        uint256 bountyId = _createBounty();
        string memory answer = "Alice's answer";
        bytes32 salt = keccak256("alice salt");
        bytes32 commitment = _commit(answer, salt, alice, bountyId);

        vm.prank(alice);
        judge.submitCommitment(bountyId, commitment);

        vm.prank(bob);
        judge.submitCommitment(bountyId, commitment);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(bytes("invalid reveal"));
        vm.prank(bob);
        judge.revealAnswer(bountyId, answer, salt);
    }

    function test_RevealOnlyWorksDuringRevealWindow() public {
        uint256 bountyId = _createBounty();
        string memory answer = "Timed answer";
        bytes32 salt = keccak256("salt");

        vm.prank(alice);
        judge.submitCommitment(bountyId, _commit(answer, salt, alice, bountyId));

        vm.expectRevert(bytes("reveal not started"));
        vm.prank(alice);
        judge.revealAnswer(bountyId, answer, salt);

        vm.warp(block.timestamp + 3 days);

        vm.expectRevert(bytes("reveal closed"));
        vm.prank(alice);
        judge.revealAnswer(bountyId, answer, salt);
    }

    function test_DuplicateCommitmentFromSameParticipantFails() public {
        uint256 bountyId = _createBounty();
        bytes32 commitment = _commit(
            "First answer",
            keccak256("salt"),
            alice,
            bountyId
        );

        vm.startPrank(alice);
        judge.submitCommitment(bountyId, commitment);

        vm.expectRevert(bytes("already committed"));
        judge.submitCommitment(bountyId, commitment);
        vm.stopPrank();
    }

    function test_UnrevealedCommitmentsAreNotEligibleSubmissions() public {
        uint256 bountyId = _createBounty();
        string memory answer = "Alice reveals";
        bytes32 aliceSalt = keccak256("alice salt");
        bytes32 bobSalt = keccak256("bob salt");

        vm.prank(alice);
        judge.submitCommitment(
            bountyId,
            _commit(answer, aliceSalt, alice, bountyId)
        );

        vm.prank(bob);
        judge.submitCommitment(
            bountyId,
            _commit("Bob stays hidden", bobSalt, bob, bountyId)
        );

        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        judge.revealAnswer(bountyId, answer, aliceSalt);

        (, , , , , , , , uint256 submissionCount, , ) = judge.getBounty(
            bountyId
        );

        assertEq(judge.getCommitmentCount(bountyId), 2);
        assertEq(submissionCount, 1);

        (address submitter, ) = judge.getSubmission(bountyId, 0);
        assertEq(submitter, alice);
    }

    function test_JudgeAllCannotRunBeforeRevealDeadline() public {
        uint256 bountyId = _createBounty();
        string memory answer = "Revealed answer";
        bytes32 salt = keccak256("salt");

        vm.prank(alice);
        judge.submitCommitment(bountyId, _commit(answer, salt, alice, bountyId));

        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        judge.revealAnswer(bountyId, answer, salt);

        vm.expectRevert(bytes("reveal still open"));
        judge.judgeAll(bountyId, "");
    }

    function _createBounty() private returns (uint256 bountyId) {
        bountyId = judge.createBounty{value: 1 ether}(
            "Privacy bounty",
            "Pick the best answer.",
            block.timestamp + 1 days,
            block.timestamp + 2 days
        );
    }

    function _commit(
        string memory answer,
        bytes32 salt,
        address submitter,
        uint256 bountyId
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(answer, salt, submitter, bountyId));
    }
}
