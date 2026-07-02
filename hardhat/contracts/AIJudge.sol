// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PrecompileConsumer} from "./utils/PrecompileConsumer.sol";

interface IRitualWallet {
    function deposit(uint256 lockDuration) external payable;

    function depositFor(address user, uint256 lockDuration) external payable;

    function withdraw(uint256 amount) external;

    function balanceOf(address) external view returns (uint256);

    function lockUntil(address) external view returns (uint256);
}

contract AIJudge is PrecompileConsumer {
    uint256 public constant MAX_SUBMISSIONS = 10;
    uint256 public constant MAX_ANSWER_LENGTH = 2_000;

    uint256 public nextBountyId = 1;

    IRitualWallet wallet =
        IRitualWallet(0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948);

    struct RevealedSubmission {
        address submitter;
        string answer;
    }

    struct Commitment {
        bytes32 commitment;
        bool revealed;
        uint256 revealedIndex;
    }

    struct Bounty {
        address owner;
        string title;
        string rubric;
        uint256 reward;
        uint256 submissionDeadline;
        uint256 revealDeadline;
        uint256 commitmentCount;
        bool judged;
        bool finalized;
        bytes aiReview;
        uint256 winnerIndex;
        RevealedSubmission[] submissions;
    }

    struct ConvoHistory {
        string storageType;
        string path;
        string secretsName;
    }

    mapping(uint256 => Bounty) public bounties;
    mapping(uint256 => mapping(address => Commitment)) private commitments;

    event BountyCreated(
        uint256 indexed bountyId,
        address indexed owner,
        string title,
        uint256 reward,
        uint256 submissionDeadline,
        uint256 revealDeadline
    );

    event CommitmentSubmitted(
        uint256 indexed bountyId,
        address indexed submitter,
        bytes32 commitment
    );

    event AnswerRevealed(
        uint256 indexed bountyId,
        uint256 indexed submissionIndex,
        address indexed submitter
    );

    event AllAnswersJudged(uint256 indexed bountyId, bytes aiReview);

    event WinnerFinalized(
        uint256 indexed bountyId,
        uint256 indexed winnerIndex,
        address indexed winner,
        uint256 reward
    );

    modifier onlyOwner(uint256 bountyId) {
        require(msg.sender == bounties[bountyId].owner, "not bounty owner");
        _;
    }

    modifier bountyExists(uint256 bountyId) {
        require(bounties[bountyId].owner != address(0), "bounty not found");
        _;
    }

    function createBounty(
        string calldata title,
        string calldata rubric,
        uint256 submissionDeadline,
        uint256 revealDeadline
    ) external payable returns (uint256 bountyId) {
        require(msg.value > 0, "reward required");
        require(
            submissionDeadline > block.timestamp,
            "submission deadline in past"
        );
        require(
            revealDeadline > submissionDeadline,
            "reveal deadline too early"
        );

        bountyId = nextBountyId++;

        Bounty storage bounty = bounties[bountyId];

        bounty.owner = msg.sender;
        bounty.title = title;
        bounty.rubric = rubric;
        bounty.reward = msg.value;
        bounty.submissionDeadline = submissionDeadline;
        bounty.revealDeadline = revealDeadline;
        bounty.winnerIndex = type(uint256).max;

        emit BountyCreated(
            bountyId,
            msg.sender,
            title,
            msg.value,
            submissionDeadline,
            revealDeadline
        );
    }

    function submitCommitment(
        uint256 bountyId,
        bytes32 commitment
    ) external bountyExists(bountyId) {
        Bounty storage bounty = bounties[bountyId];

        require(block.timestamp < bounty.submissionDeadline, "submissions closed");
        require(!bounty.judged, "already judged");
        require(!bounty.finalized, "already finalized");
        require(commitment != bytes32(0), "empty commitment");
        require(bounty.commitmentCount < MAX_SUBMISSIONS, "too many submissions");
        require(
            commitments[bountyId][msg.sender].commitment == bytes32(0),
            "already committed"
        );

        commitments[bountyId][msg.sender] = Commitment({
            commitment: commitment,
            revealed: false,
            revealedIndex: type(uint256).max
        });
        bounty.commitmentCount++;

        emit CommitmentSubmitted(bountyId, msg.sender, commitment);
    }

    function revealAnswer(
        uint256 bountyId,
        string calldata answer,
        bytes32 salt
    ) external bountyExists(bountyId) {
        Bounty storage bounty = bounties[bountyId];
        Commitment storage userCommitment = commitments[bountyId][msg.sender];

        require(
            block.timestamp >= bounty.submissionDeadline,
            "reveal not started"
        );
        require(block.timestamp < bounty.revealDeadline, "reveal closed");
        require(!bounty.judged, "already judged");
        require(!bounty.finalized, "already finalized");
        require(userCommitment.commitment != bytes32(0), "no commitment");
        require(!userCommitment.revealed, "already revealed");
        require(bytes(answer).length <= MAX_ANSWER_LENGTH, "answer too long");
        require(
            keccak256(abi.encodePacked(answer, salt, msg.sender, bountyId)) ==
                userCommitment.commitment,
            "invalid reveal"
        );

        bounty.submissions.push(
            RevealedSubmission({submitter: msg.sender, answer: answer})
        );
        userCommitment.revealed = true;
        userCommitment.revealedIndex = bounty.submissions.length - 1;

        emit AnswerRevealed(
            bountyId,
            bounty.submissions.length - 1,
            msg.sender
        );
    }

    function judgeAll(
        uint256 bountyId,
        bytes calldata llmInput
    ) external bountyExists(bountyId) onlyOwner(bountyId) {
        Bounty storage bounty = bounties[bountyId];

        require(!bounty.judged, "already judged");
        require(!bounty.finalized, "already finalized");
        require(block.timestamp >= bounty.revealDeadline, "reveal still open");
        require(bounty.submissions.length > 0, "no submissions");

        bytes memory output = _executePrecompile(
            LLM_INFERENCE_PRECOMPILE,
            llmInput
        );

        (
            bool hasError,
            bytes memory completionData,
            ,
            string memory errorMessage,

        ) = abi.decode(output, (bool, bytes, bytes, string, ConvoHistory));

        require(!hasError, errorMessage);

        bounty.judged = true;
        bounty.aiReview = completionData;

        emit AllAnswersJudged(bountyId, completionData);
    }

    function finalizeWinner(
        uint256 bountyId,
        uint256 winnerIndex
    ) external bountyExists(bountyId) onlyOwner(bountyId) {
        Bounty storage bounty = bounties[bountyId];

        require(bounty.judged, "not judged yet");
        require(!bounty.finalized, "already finalized");
        require(winnerIndex < bounty.submissions.length, "invalid winner");

        bounty.finalized = true;
        bounty.winnerIndex = winnerIndex;

        address winner = bounty.submissions[winnerIndex].submitter;
        uint256 reward = bounty.reward;
        bounty.reward = 0;

        (bool ok, ) = payable(winner).call{value: reward}("");
        require(ok, "payment failed");

        emit WinnerFinalized(bountyId, winnerIndex, winner, reward);
    }

    function getBounty(
        uint256 bountyId
    )
        external
        view
        bountyExists(bountyId)
        returns (
            address owner,
            string memory title,
            string memory rubric,
            uint256 reward,
            uint256 submissionDeadline,
            uint256 revealDeadline,
            bool judged,
            bool finalized,
            uint256 submissionCount,
            uint256 winnerIndex,
            bytes memory aiReview
        )
    {
        Bounty storage bounty = bounties[bountyId];

        owner = bounty.owner;
        title = bounty.title;
        rubric = bounty.rubric;
        reward = bounty.reward;
        submissionDeadline = bounty.submissionDeadline;
        revealDeadline = bounty.revealDeadline;
        judged = bounty.judged;
        finalized = bounty.finalized;
        submissionCount = bounty.submissions.length;
        winnerIndex = bounty.winnerIndex;
        aiReview = bounty.aiReview;
    }

    function getSubmission(
        uint256 bountyId,
        uint256 index
    )
        external
        view
        bountyExists(bountyId)
        returns (address submitter, string memory answer)
    {
        Bounty storage bounty = bounties[bountyId];

        require(index < bounty.submissions.length, "invalid index");

        RevealedSubmission storage submission = bounty.submissions[index];

        return (submission.submitter, submission.answer);
    }

    function getCommitment(
        uint256 bountyId,
        address submitter
    )
        external
        view
        bountyExists(bountyId)
        returns (bytes32 commitment, bool revealed, uint256 revealedIndex)
    {
        Commitment storage userCommitment = commitments[bountyId][submitter];

        return (
            userCommitment.commitment,
            userCommitment.revealed,
            userCommitment.revealedIndex
        );
    }

    function getCommitmentCount(
        uint256 bountyId
    ) external view bountyExists(bountyId) returns (uint256) {
        return bounties[bountyId].commitmentCount;
    }
}
