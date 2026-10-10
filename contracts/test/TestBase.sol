// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal Foundry cheatcode interface so these tests need no external
///      dependencies (no forge-std install required).
interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectEmit(bool, bool, bool, bool) external;
    function warp(uint256) external;
    function assume(bool) external;
    function label(address, string calldata) external;
}

/// @dev Tiny assertion harness used in place of forge-std's Test base.
contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 private _failures;

    function assertTrue(bool condition, string memory message) internal {
        if (!condition) {
            _failures++;
            revert(message);
        }
    }

    function assertFalse(bool condition, string memory message) internal {
        assertTrue(!condition, message);
    }

    function assertEq(uint256 a, uint256 b, string memory message) internal {
        assertTrue(a == b, message);
    }

    function assertEq(int256 a, int256 b, string memory message) internal {
        assertTrue(a == b, message);
    }

    function assertEq(address a, address b, string memory message) internal {
        assertTrue(a == b, message);
    }

    function assertEq(bool a, bool b, string memory message) internal {
        assertTrue(a == b, message);
    }
}
