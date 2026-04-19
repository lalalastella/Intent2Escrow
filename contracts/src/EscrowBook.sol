// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title EscrowBook
/// @notice Natural-language-driven escrow for Intent2Escrow (MSX hackathon).
/// @dev    State machine:
///           Created -> Funded -> EvidenceSubmitted -> Released
///                         \------------------------> Refunded (past releaseDeadline)
///         If evidenceRequired=false, Funded -> Released is allowed directly.
///         Off-chain flow: LLM parses a deal memo into EscrowParams; front-end
///         calls createEscrow + fund. Contract is source of truth for state.
contract EscrowBook is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Types ============

    enum Status {
        None,
        Created,
        Funded,
        EvidenceSubmitted,
        Released,
        Refunded
    }

    struct Escrow {
        address payer;
        address payee;
        address token;
        uint256 amount;
        uint64  fundDeadline;       // must fund before this
        uint64  releaseDeadline;    // past this, payer may refund
        string  metadataCID;        // IPFS CID of full deal memo + AI spec
        string  evidenceCID;        // IPFS CID of delivery evidence (empty until submitted)
        bool    evidenceRequired;   // if true, release() requires EvidenceSubmitted state
        Status  status;
    }

    struct EscrowParams {
        address payee;
        address token;
        uint256 amount;
        uint64  fundDeadline;
        uint64  releaseDeadline;
        string  metadataCID;
        bool    evidenceRequired;
    }

    // ============ State ============

    uint256 public nextEscrowId;
    mapping(uint256 => Escrow) public escrows;

    // ============ Events ============

    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed payer,
        address indexed payee,
        address token,
        uint256 amount,
        string  metadataCID,
        bool    evidenceRequired
    );
    event Funded(uint256 indexed escrowId, uint256 amount);
    event EvidenceSubmitted(uint256 indexed escrowId, string evidenceCID);
    event Released(uint256 indexed escrowId, address indexed to, uint256 amount);
    event Refunded(uint256 indexed escrowId, address indexed to, uint256 amount);

    // ============ Errors ============

    error InvalidStatus(uint256 escrowId, Status expected, Status actual);
    error NotPayer();
    error NotPayee();
    error InvalidAmount();
    error InvalidAddress();
    error InvalidDeadlines();
    error FundDeadlinePassed();
    error ReleaseDeadlineNotReached();
    error EvidenceRequiredNotSubmitted();

    // ============ External ============

    /// @notice Payer creates an escrow skeleton. No funds move yet.
    function createEscrow(EscrowParams calldata p) external returns (uint256 escrowId) {
        if (p.amount == 0) revert InvalidAmount();
        if (p.payee == address(0) || p.token == address(0)) revert InvalidAddress();
        if (p.fundDeadline <= block.timestamp) revert InvalidDeadlines();
        if (p.releaseDeadline <= p.fundDeadline) revert InvalidDeadlines();

        escrowId = nextEscrowId++;
        escrows[escrowId] = Escrow({
            payer:             msg.sender,
            payee:             p.payee,
            token:             p.token,
            amount:            p.amount,
            fundDeadline:      p.fundDeadline,
            releaseDeadline:   p.releaseDeadline,
            metadataCID:       p.metadataCID,
            evidenceCID:       "",
            evidenceRequired:  p.evidenceRequired,
            status:            Status.Created
        });

        emit EscrowCreated(
            escrowId,
            msg.sender,
            p.payee,
            p.token,
            p.amount,
            p.metadataCID,
            p.evidenceRequired
        );
    }

    /// @notice Payer pulls ERC-20 into escrow. Requires prior approve().
    function fund(uint256 escrowId) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        if (e.status != Status.Created) revert InvalidStatus(escrowId, Status.Created, e.status);
        if (msg.sender != e.payer) revert NotPayer();
        if (block.timestamp > e.fundDeadline) revert FundDeadlinePassed();

        e.status = Status.Funded;
        IERC20(e.token).safeTransferFrom(msg.sender, address(this), e.amount);
        emit Funded(escrowId, e.amount);
    }

    /// @notice Payee posts an IPFS CID pointing at delivery evidence.
    /// @dev    Evidence is informational only — release still requires payer approval.
    function submitEvidence(uint256 escrowId, string calldata evidenceCID) external {
        Escrow storage e = escrows[escrowId];
        if (e.status != Status.Funded) revert InvalidStatus(escrowId, Status.Funded, e.status);
        if (msg.sender != e.payee) revert NotPayee();

        e.evidenceCID = evidenceCID;
        e.status = Status.EvidenceSubmitted;
        emit EvidenceSubmitted(escrowId, evidenceCID);
    }

    /// @notice Payer approves release. Funds go to payee.
    /// @dev    If evidenceRequired=true, must be in EvidenceSubmitted state.
    ///         If evidenceRequired=false, Funded or EvidenceSubmitted both allowed.
    function release(uint256 escrowId) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        if (msg.sender != e.payer) revert NotPayer();

        if (e.evidenceRequired) {
            if (e.status != Status.EvidenceSubmitted) {
                revert EvidenceRequiredNotSubmitted();
            }
        } else {
            if (e.status != Status.Funded && e.status != Status.EvidenceSubmitted) {
                revert InvalidStatus(escrowId, Status.Funded, e.status);
            }
        }

        e.status = Status.Released;
        IERC20(e.token).safeTransfer(e.payee, e.amount);
        emit Released(escrowId, e.payee, e.amount);
    }

    /// @notice Payer reclaims funds after releaseDeadline if not released.
    function refund(uint256 escrowId) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        if (e.status != Status.Funded && e.status != Status.EvidenceSubmitted) {
            revert InvalidStatus(escrowId, Status.Funded, e.status);
        }
        if (msg.sender != e.payer) revert NotPayer();
        if (block.timestamp < e.releaseDeadline) revert ReleaseDeadlineNotReached();

        e.status = Status.Refunded;
        IERC20(e.token).safeTransfer(e.payer, e.amount);
        emit Refunded(escrowId, e.payer, e.amount);
    }

    // ============ Views ============

    function getEscrow(uint256 escrowId) external view returns (Escrow memory) {
        return escrows[escrowId];
    }
}
