// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EscrowBook} from "../src/EscrowBook.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EscrowBookTest is Test {
    EscrowBook public book;
    MockUSDC   public usdc;

    address payer = address(0xA11CE);
    address payee = address(0xB0B);

    function setUp() public {
        book = new EscrowBook();
        usdc = new MockUSDC();
        usdc.mint(payer, 1_000e18);
    }

    // -------- helpers --------

    function _defaultParams(bool evidenceRequired)
        internal
        view
        returns (EscrowBook.EscrowParams memory)
    {
        return EscrowBook.EscrowParams({
            payee:             payee,
            token:             address(usdc),
            amount:            50e18,
            fundDeadline:      uint64(block.timestamp + 1 days),
            releaseDeadline:   uint64(block.timestamp + 7 days),
            metadataCID:       "QmFakeMetadataCid",
            evidenceRequired:  evidenceRequired
        });
    }

    function _createAndFund(bool evidenceRequired) internal returns (uint256 id) {
        vm.prank(payer);
        id = book.createEscrow(_defaultParams(evidenceRequired));

        vm.prank(payer);
        usdc.approve(address(book), 50e18);
        vm.prank(payer);
        book.fund(id);
    }

    // -------- happy paths --------

    function test_HappyPath_EvidenceRequired_CreateFundEvidenceRelease() public {
        uint256 id = _createAndFund(true);

        vm.prank(payee);
        book.submitEvidence(id, "QmEvidenceCid");

        uint256 before = usdc.balanceOf(payee);
        vm.prank(payer);
        book.release(id);
        assertEq(usdc.balanceOf(payee), before + 50e18);
    }

    function test_HappyPath_NoEvidence_DirectRelease() public {
        uint256 id = _createAndFund(false);

        // Payer can release directly from Funded when evidence not required.
        uint256 before = usdc.balanceOf(payee);
        vm.prank(payer);
        book.release(id);
        assertEq(usdc.balanceOf(payee), before + 50e18);
    }

    // -------- refund path --------

    function test_Refund_AfterReleaseDeadline() public {
        uint256 id = _createAndFund(true);
        vm.warp(block.timestamp + 8 days);

        uint256 before = usdc.balanceOf(payer);
        vm.prank(payer);
        book.refund(id);
        assertEq(usdc.balanceOf(payer), before + 50e18);
    }

    // -------- access control --------

    function test_RevertWhen_NonPayerTriesRelease() public {
        uint256 id = _createAndFund(true);
        vm.prank(payee);
        book.submitEvidence(id, "QmE");

        vm.prank(payee); // payee cannot release
        vm.expectRevert(EscrowBook.NotPayer.selector);
        book.release(id);
    }

    // -------- evidence enforcement --------

    function test_RevertWhen_ReleaseWithoutRequiredEvidence() public {
        uint256 id = _createAndFund(true);

        // No evidence submitted. evidenceRequired=true. Must revert.
        vm.prank(payer);
        vm.expectRevert(EscrowBook.EvidenceRequiredNotSubmitted.selector);
        book.release(id);
    }

    // -------- deadline enforcement --------

    function test_RevertWhen_RefundBeforeDeadline() public {
        uint256 id = _createAndFund(true);
        vm.prank(payer);
        vm.expectRevert(EscrowBook.ReleaseDeadlineNotReached.selector);
        book.refund(id);
    }

    // -------- input validation --------

    function test_RevertWhen_DeadlinesInverted() public {
        EscrowBook.EscrowParams memory p = _defaultParams(true);
        p.fundDeadline    = uint64(block.timestamp + 7 days);
        p.releaseDeadline = uint64(block.timestamp + 1 days);

        vm.prank(payer);
        vm.expectRevert(EscrowBook.InvalidDeadlines.selector);
        book.createEscrow(p);
    }
}
