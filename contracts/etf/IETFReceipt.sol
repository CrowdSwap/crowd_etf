// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface IETFReceipt {
    struct TokenDetail {
        address token;
        uint256 amount;
        uint256 price;
    }

    struct Invest {
        uint256 id;
        uint256 planId;
        uint256 createTime;
    }

    struct InvestDetail {
        uint256 id;
        uint256 planId;
        uint256 createTime;
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
        uint256 planId,
        TokenDetail[] memory tokenDetails
    ) external returns (uint256);

    function burn(uint256 tokenId) external;

    function burnAndMint(
        uint256 tokenId,
        address to,
        uint256 planId,
        TokenDetail[] memory tokenDetails
    ) external;

    function planByPlanId(uint256 id) external view returns (PlanDetail memory);

    function tokenByTokenId(
        address userAddress,
        uint256 tokenId
    ) external view returns (InvestDetail memory);
}
