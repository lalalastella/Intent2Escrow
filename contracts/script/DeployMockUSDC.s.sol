// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

/// @notice Deploy MockUSDC to Base Sepolia and mint 10,000 mUSDC to the deployer.
///         Run:
///           forge script script/DeployMockUSDC.s.sol:DeployMockUSDC \
///             --rpc-url $BASE_SEPOLIA_RPC_URL \
///             --private-key $PRIVATE_KEY \
///             --broadcast \
///             --verify \
///             --etherscan-api-key $BASESCAN_API_KEY
contract DeployMockUSDC is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);
        MockUSDC usdc = new MockUSDC();
        // 10,000 mUSDC, 6 decimals -> 10_000 * 10^6
        usdc.mint(deployer, 10_000 * 10**6);
        vm.stopBroadcast();

        console.log("MockUSDC deployed at:", address(usdc));
        console.log("Minted 10,000 mUSDC to:", deployer);
    }
}
