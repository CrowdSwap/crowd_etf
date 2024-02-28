// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "../../libraries/UniERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./CrowdTokenWrapper.sol";

contract CrowdswapV1Test {

    using UniERC20 for IERC20;
    using SafeERC20 for IERC20;

    constructor(){}
    
    function swap(
        IERC20 _fromToken,
        IERC20 _destToken,
        address payable _receiver,
        uint256 _amountIn,
        uint8 _dexFlag,
        bytes calldata _data
    )
    external payable returns (uint256 returnAmount){ 

        require(msg.value == (_fromToken.isETH() ? _amountIn : 0), "ce06");

        if (!_fromToken.isETH()) {
            _fromToken.safeTransferFrom(msg.sender, address(this), _amountIn);
        }

        CrowdTokenWrapper(address(_destToken)).mint(_receiver, _amountIn);
       
        return _amountIn;
    }
}
