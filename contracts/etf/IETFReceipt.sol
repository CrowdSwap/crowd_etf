// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface IETFReceipt {
    struct TokenDetail {
        address token;
        uint128 amount;
        uint64 price;
    }

    struct Invest {
        uint32 id;
        uint16 planId;
        uint32 createTime;
    }

    struct InvestDetail {
        uint32 id;
        uint16 planId;
        uint32 createTime;
        TokenDetail[] tokenDetails;
    }

    struct TokenPercentage {
        address token;
        uint16 percentage;
    }

    struct Plan {
        string name;
        bool active;
    }

    struct PlanDetail {
        uint256 id;
        string name;
        bool active;
        TokenPercentage[] tokenPercentages;
    }

    function mint(
        address to,
        uint16 planId,
        TokenDetail[] memory tokenDetails
    ) external returns (uint256);

    function burn(uint256 tokenId) external;

    function burnAndMint(
        uint32 tokenId,
        address to,
        uint16 planId,
        TokenDetail[] memory tokenDetails
    ) external;

    function planByPlanId(uint256 id) external view returns (PlanDetail memory);

    function tokenByTokenId(
        address userAddress,
        uint256 tokenId
    ) external view returns (InvestDetail memory);
}
