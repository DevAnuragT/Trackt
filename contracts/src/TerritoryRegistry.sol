// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface for the reward token the registry mints from.
interface IRunRewardToken {
    function mint(address to, uint256 amount) external;
}

/// @title TerritoryRegistry
/// @notice On-chain registry of real-world running territories for Trackt.
///         A runner who closes a GPS loop calls {claimTerritory}. If the
///         territory is unclaimed it is minted to them; if it belongs to a
///         rival it is conquered and ownership transfers. Each successful claim
///         or conquest mints a $TRACKT reward (best-effort).
/// @dev Coordinates are stored as fixed-point integers (degrees * 1e6) so the
///      client can send signed lat/lng without floating point.
contract TerritoryRegistry {
    struct Territory {
        address owner;
        int256 centerLat; // degrees * 1e6
        int256 centerLng; // degrees * 1e6
        uint256 areaSqMeters;
        uint256 claimedAt;
        bool exists;
    }

    // ----- State -----
    mapping(uint256 => Territory) private _territories;
    mapping(address => uint256) public territoryCountOf;
    uint256 public totalTerritories;

    address public owner;
    IRunRewardToken public rewardToken;
    uint256 public claimReward; // $TRACKT (wei) minted per claim/conquest

    /// @notice Upper bound on a single territory's area (anti-cheat sanity).
    uint256 public maxAreaSqMeters;

    // ----- Events -----
    event TerritoryClaimed(
        uint256 indexed territoryId,
        address indexed owner,
        int256 centerLat,
        int256 centerLng,
        uint256 areaSqMeters,
        uint256 timestamp
    );
    event TerritoryConquered(
        uint256 indexed stolenTerritoryId,
        address indexed previousOwner,
        address indexed conqueror,
        uint256 areaStolen
    );
    event RewardTokenUpdated(address indexed token);
    event ClaimRewardUpdated(uint256 reward);
    event MaxAreaUpdated(uint256 maxAreaSqMeters);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ----- Errors -----
    error NotOwner();
    error ZeroAddress();
    error InvalidArea();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address rewardToken_, uint256 claimReward_) {
        owner = msg.sender;
        rewardToken = IRunRewardToken(rewardToken_);
        claimReward = claimReward_;
        maxAreaSqMeters = 1_000_000; // 1 km^2 default cap
        emit OwnershipTransferred(address(0), msg.sender);
        emit RewardTokenUpdated(rewardToken_);
        emit ClaimRewardUpdated(claimReward_);
    }

    // ----- Admin -----

    function setRewardToken(address token) external onlyOwner {
        rewardToken = IRunRewardToken(token);
        emit RewardTokenUpdated(token);
    }

    function setClaimReward(uint256 reward) external onlyOwner {
        claimReward = reward;
        emit ClaimRewardUpdated(reward);
    }

    function setMaxArea(uint256 maxArea) external onlyOwner {
        if (maxArea == 0) revert InvalidArea();
        maxAreaSqMeters = maxArea;
        emit MaxAreaUpdated(maxArea);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ----- Core gameplay -----

    /// @notice Claim or conquer the territory identified by `territoryId`.
    /// @param territoryId Stable id for the territory (client-derived).
    /// @param lat Center latitude, degrees * 1e6.
    /// @param lng Center longitude, degrees * 1e6.
    /// @param area Enclosed area in square meters.
    function claimTerritory(uint256 territoryId, int256 lat, int256 lng, uint256 area) external {
        if (area == 0 || area > maxAreaSqMeters) revert InvalidArea();

        Territory storage t = _territories[territoryId];

        if (!t.exists) {
            // Fresh claim.
            t.owner = msg.sender;
            t.centerLat = lat;
            t.centerLng = lng;
            t.areaSqMeters = area;
            t.claimedAt = block.timestamp;
            t.exists = true;

            totalTerritories += 1;
            territoryCountOf[msg.sender] += 1;

            emit TerritoryClaimed(territoryId, msg.sender, lat, lng, area, block.timestamp);
            _reward(msg.sender);
            return;
        }

        if (t.owner != msg.sender) {
            // Conquest: ownership changes hands.
            address previousOwner = t.owner;
            uint256 areaStolen = t.areaSqMeters;

            // Checks-effects: update ownership counters before any external call.
            if (territoryCountOf[previousOwner] > 0) {
                territoryCountOf[previousOwner] -= 1;
            }
            territoryCountOf[msg.sender] += 1;

            t.owner = msg.sender;
            t.centerLat = lat;
            t.centerLng = lng;
            t.areaSqMeters = area;
            t.claimedAt = block.timestamp;

            emit TerritoryConquered(territoryId, previousOwner, msg.sender, areaStolen);
            emit TerritoryClaimed(territoryId, msg.sender, lat, lng, area, block.timestamp);
            _reward(msg.sender);
            return;
        }

        // Owner re-affirming their own territory: refresh geometry, no reward.
        t.centerLat = lat;
        t.centerLng = lng;
        t.areaSqMeters = area;
        t.claimedAt = block.timestamp;
        emit TerritoryClaimed(territoryId, msg.sender, lat, lng, area, block.timestamp);
    }

    /// @dev Best-effort reward mint. A misconfigured/unauthorized token must not
    ///      brick territory claims, so minting failures are swallowed.
    function _reward(address to) internal {
        if (address(rewardToken) == address(0) || claimReward == 0) return;
        try rewardToken.mint(to, claimReward) {} catch {}
    }

    // ----- Views -----

    function getTerritory(uint256 territoryId) external view returns (Territory memory) {
        return _territories[territoryId];
    }

    function exists(uint256 territoryId) external view returns (bool) {
        return _territories[territoryId].exists;
    }

    function ownerOf(uint256 territoryId) external view returns (address) {
        return _territories[territoryId].owner;
    }
}
