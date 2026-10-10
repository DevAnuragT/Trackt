// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "./TestBase.sol";
import {TerritoryRegistry} from "../src/TerritoryRegistry.sol";
import {RunRewardToken} from "../src/RunRewardToken.sol";

contract TerritoryRegistryTest is TestBase {
    TerritoryRegistry internal registry;
    RunRewardToken internal token;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant REWARD = 100 ether;
    uint256 internal constant TID = 42;

    function setUp() public {
        token = new RunRewardToken();
        registry = new TerritoryRegistry(address(token), REWARD);
        // Authorize the registry to mint rewards.
        token.setMinter(address(registry), true);
    }

    // ----- Construction -----

    function test_Constructor() public {
        assertEq(registry.owner(), address(this), "owner");
        assertEq(registry.claimReward(), REWARD, "claimReward");
        assertEq(address(registry.rewardToken()), address(token), "reward token");
        assertEq(registry.maxAreaSqMeters(), uint256(1_000_000), "default max area");
        assertEq(registry.totalTerritories(), uint256(0), "no territories yet");
    }

    // ----- Fresh claim -----

    function test_ClaimFreshTerritory() public {
        vm.prank(alice);
        registry.claimTerritory(TID, 40_781200, -73_966500, 16_850);

        TerritoryRegistry.Territory memory t = registry.getTerritory(TID);
        assertTrue(t.exists, "exists");
        assertEq(t.owner, alice, "owner is alice");
        assertEq(t.centerLat, int256(40_781200), "lat stored");
        assertEq(t.centerLng, int256(-73_966500), "lng (negative) stored");
        assertEq(t.areaSqMeters, uint256(16_850), "area stored");

        assertEq(registry.totalTerritories(), uint256(1), "total incremented");
        assertEq(registry.territoryCountOf(alice), uint256(1), "alice count");
        assertEq(token.balanceOf(alice), REWARD, "alice rewarded");
    }

    function test_Claim_RevertsOnZeroArea() public {
        vm.prank(alice);
        vm.expectRevert(TerritoryRegistry.InvalidArea.selector);
        registry.claimTerritory(TID, 0, 0, 0);
    }

    function test_Claim_RevertsAboveMaxArea() public {
        vm.prank(alice);
        vm.expectRevert(TerritoryRegistry.InvalidArea.selector);
        registry.claimTerritory(TID, 0, 0, 1_000_001);
    }

    // ----- Conquest -----

    function test_ConquerRivalTerritory() public {
        vm.prank(alice);
        registry.claimTerritory(TID, 10, 10, 5_000);
        assertEq(registry.territoryCountOf(alice), uint256(1), "alice owns 1");

        vm.prank(bob);
        registry.claimTerritory(TID, 11, 11, 6_000);

        TerritoryRegistry.Territory memory t = registry.getTerritory(TID);
        assertEq(t.owner, bob, "bob conquered");
        assertEq(t.areaSqMeters, uint256(6_000), "area updated to conqueror's");

        assertEq(registry.territoryCountOf(alice), uint256(0), "alice lost it");
        assertEq(registry.territoryCountOf(bob), uint256(1), "bob gained it");
        assertEq(registry.totalTerritories(), uint256(1), "still one territory");

        assertEq(token.balanceOf(bob), REWARD, "bob rewarded for conquest");
    }

    // ----- Self re-affirm -----

    function test_OwnerReaffirm_NoRewardNoCountChange() public {
        vm.startPrank(alice);
        registry.claimTerritory(TID, 10, 10, 5_000);
        registry.claimTerritory(TID, 12, 12, 7_000); // same owner refreshes
        vm.stopPrank();

        TerritoryRegistry.Territory memory t = registry.getTerritory(TID);
        assertEq(t.areaSqMeters, uint256(7_000), "geometry refreshed");
        assertEq(registry.territoryCountOf(alice), uint256(1), "count unchanged");
        assertEq(registry.totalTerritories(), uint256(1), "total unchanged");
        // Only the first claim pays a reward.
        assertEq(token.balanceOf(alice), REWARD, "rewarded once only");
    }

    // ----- Reward is best-effort -----

    function test_Claim_SucceedsWhenRegistryNotMinter() public {
        // Revoke the registry's minting rights; claims must still succeed.
        token.setMinter(address(registry), false);

        vm.prank(alice);
        registry.claimTerritory(TID, 1, 1, 1_000);

        assertTrue(registry.getTerritory(TID).exists, "claim still recorded");
        assertEq(token.balanceOf(alice), uint256(0), "no reward minted");
    }

    function test_Claim_SucceedsWhenNoRewardToken() public {
        registry.setRewardToken(address(0));
        vm.prank(alice);
        registry.claimTerritory(TID, 1, 1, 1_000);
        assertTrue(registry.getTerritory(TID).exists, "claim recorded without token");
    }

    // ----- Admin -----

    function test_SetClaimReward() public {
        registry.setClaimReward(250 ether);
        assertEq(registry.claimReward(), 250 ether, "reward updated");
        vm.prank(alice);
        registry.claimTerritory(TID, 1, 1, 1_000);
        assertEq(token.balanceOf(alice), 250 ether, "new reward applied");
    }

    function test_SetMaxArea() public {
        registry.setMaxArea(500);
        vm.prank(alice);
        vm.expectRevert(TerritoryRegistry.InvalidArea.selector);
        registry.claimTerritory(TID, 1, 1, 501);
    }

    function test_SetMaxArea_RevertsOnZero() public {
        vm.expectRevert(TerritoryRegistry.InvalidArea.selector);
        registry.setMaxArea(0);
    }

    function test_AdminFns_RevertForNonOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(TerritoryRegistry.NotOwner.selector);
        registry.setClaimReward(1);
        vm.expectRevert(TerritoryRegistry.NotOwner.selector);
        registry.setMaxArea(1);
        vm.expectRevert(TerritoryRegistry.NotOwner.selector);
        registry.setRewardToken(address(0));
        vm.expectRevert(TerritoryRegistry.NotOwner.selector);
        registry.transferOwnership(bob);
        vm.stopPrank();
    }

    function test_TransferOwnership() public {
        registry.transferOwnership(alice);
        assertEq(registry.owner(), alice, "ownership moved");
    }

    // ----- Views -----

    function test_Views() public {
        assertFalse(registry.exists(TID), "not yet");
        assertEq(registry.ownerOf(TID), address(0), "no owner yet");
        vm.prank(alice);
        registry.claimTerritory(TID, 1, 1, 1_000);
        assertTrue(registry.exists(TID), "now exists");
        assertEq(registry.ownerOf(TID), alice, "owner view");
    }

    // ----- Multiple territories -----

    function test_MultipleTerritoriesPerOwner() public {
        vm.startPrank(alice);
        registry.claimTerritory(1, 1, 1, 100);
        registry.claimTerritory(2, 2, 2, 200);
        registry.claimTerritory(3, 3, 3, 300);
        vm.stopPrank();
        assertEq(registry.territoryCountOf(alice), uint256(3), "alice owns 3");
        assertEq(registry.totalTerritories(), uint256(3), "3 total");
        assertEq(token.balanceOf(alice), REWARD * 3, "rewarded per claim");
    }

    // ----- Fuzz -----

    function testFuzz_ClaimStoresValues(uint256 id, int256 lat, int256 lng, uint256 area) public {
        area = bound(area, 1, registry.maxAreaSqMeters());
        vm.prank(alice);
        registry.claimTerritory(id, lat, lng, area);
        TerritoryRegistry.Territory memory t = registry.getTerritory(id);
        assertEq(t.owner, alice, "fuzz owner");
        assertEq(t.centerLat, lat, "fuzz lat");
        assertEq(t.centerLng, lng, "fuzz lng");
        assertEq(t.areaSqMeters, area, "fuzz area");
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        uint256 range = max - min + 1;
        return min + (x % range);
    }
}
