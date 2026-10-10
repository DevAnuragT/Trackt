// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RunRewardToken} from "../src/RunRewardToken.sol";
import {TerritoryRegistry} from "../src/TerritoryRegistry.sol";

/// @dev Minimal broadcasting cheatcode interface (no forge-std dependency).
interface VmScript {
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function envUint(string calldata name) external view returns (uint256);
    function envOr(string calldata name, uint256 defaultValue) external view returns (uint256);
}

/// @title Deploy
/// @notice Deploys RunRewardToken + TerritoryRegistry to Monad Testnet and wires
///         the registry as an authorized token minter.
///
/// Usage:
///   PRIVATE_KEY=0x... forge script script/Deploy.s.sol:Deploy \
///       --rpc-url https://testnet-rpc.monad.xyz --broadcast
contract Deploy {
    VmScript internal constant vm =
        VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (RunRewardToken token, TerritoryRegistry registry) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 reward = vm.envOr("CLAIM_REWARD", uint256(100 ether));

        vm.startBroadcast(pk);

        token = new RunRewardToken();
        registry = new TerritoryRegistry(address(token), reward);
        token.setMinter(address(registry), true);

        vm.stopBroadcast();
    }
}
