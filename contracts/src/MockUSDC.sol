// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDC
/// @notice Demo-only ERC20 with USDC-style 6 decimals and a public mint().
/// @dev    Six decimals matches real USDC and the backend parser
///         (MUSDC_DECIMALS = 6 in app/parser.py). Deploying any other
///         decimals will silently break the frontend's amount math.
///         Public mint() is intentional — this is a faucet token for
///         the hackathon demo, not a production asset.
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Anyone can mint to anyone. Demo-only; never deploy to mainnet.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
