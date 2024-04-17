// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../helpers/OwnableUpgradeable.sol";
import "../libraries/UniERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./IETFReceipt.sol";

contract ETFProxy is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using UniERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
    * @notice Struct representing information about a token swap.
    * @member token The token contract involved in the swap. (tokenOut for invest and tokenIn for withdraw)
    * @member price The price of the token swap. (tokenOut for invest and tokenIn for withdraw)
    * @member data Additional data related to the swap.
    */
    struct SwapInfo {
        IERC20Upgradeable token;
        uint64 price;
        bytes data;
    }

    /**
     * @dev A struct containing parameters needed to calculate fees
     * @member feeTo The address of feeTo
     * @member investFee The fee of invest step
     * @member withdrawFee The fee of withdraw step
     */
    struct FeeInfo {
        address payable feeTo;
        uint256 investFee;
        uint256 withdrawFee;
    }

    uint256 public constant MAX_FEE = 1e20; //100%

    uint16 public constant MAX_P = 1e4; //100%

    FeeInfo public feeInfo;

    address public ETFReceiptAddress;
    address public swapContract;

    event FeeDeducted(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 totalFee
    );

    event SetFee(
        address indexed user,
        address feeTo,
        uint256 investFee,
        uint256 withdrawFee
    );

    event Invested(
        address indexed user,
        uint256 indexed investId,
        uint256 indexed planId,
        address initiator
    );

    event Withdrawn(
        address indexed user,
        uint256 indexed investId,
        uint256 indexed planId
    );

    event SetSwapContract(address indexed swapContract);
    event SetETFReceiptAddress(address indexed ETFReceipt);

    event coinTransfer(address indexed from, address indexed to, uint256 value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
    * @notice Initializes the contract with provided parameters.
    * @param _ETFReceiptAddress The address of the ETFReceipt contract.
    * @param _swapContract The address of the swap contract.
    * @param _feeInfo A FeeInfo structure containing information about fees.
    * @dev Initializes the contract by setting the ETFReceiptAddress, swapContract,
    *      and configuring fees.
    */
    function initialize(
        address _ETFReceiptAddress,
        address _swapContract,
        FeeInfo memory _feeInfo
    ) public initializer {
        _requiredValidAddress(_ETFReceiptAddress);
        _requiredValidAddress(_swapContract);

        OwnableUpgradeable.initialize();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        ETFReceiptAddress = _ETFReceiptAddress;
        swapContract = _swapContract;

        _setFee(_feeInfo);
    }

    /**
     * @notice Allows a user to invest in a specified plan.
     * @param _userAddress The address of the user making the investment.
     * @param _planId The ID of the investment plan.
     * @param _tokenIn The token to be invested.
     * @param _amountIn The amount of the token to be invested.
     * @param _swaps An array of SwapInfo structures containing information about token swaps.
     * @dev Allows users to invest in a specified plan by providing the necessary tokens and executing swaps.
     *      Requires the plan to be active and validates the provided swap information.
     *      Handles token transfers and fee deductions.
     */
    function invest(
        address _userAddress,
        uint256 _planId,
        IERC20Upgradeable _tokenIn,
        uint256 _amountIn,
        SwapInfo[] memory _swaps
    ) external payable nonReentrant whenNotPaused {
        require(_amountIn < type(uint128).max && _planId < type(uint16).max, "ETFProxy: amountIn or planId overflowed");

        IETFReceipt _ETFReceipt = IETFReceipt(ETFReceiptAddress);

        IETFReceipt.PlanDetail memory _planDetail = _ETFReceipt.planByPlanId(
            _planId
        );

        require(_planDetail.active, "ETFProxy: Plan is not active.");


        _requiredValidSwapInfo(_swaps, _planDetail.tokenPercentages);


        if (!_tokenIn.isETH()) {
            _transferTokenFromTo(
                _tokenIn,
                msg.sender,
                address(this),
                _amountIn
            );
        } else {
            require(msg.value == _amountIn, "ETFProxy: invalid msg.value");
        }

        //Decrease fee
        uint256 _feePercentage = feeInfo.investFee;
        uint256 _amount = _deductFee(_feePercentage, _tokenIn, _amountIn);

        IETFReceipt.TokenDetail[]
            memory _tokenDetails = new IETFReceipt.TokenDetail[](_swaps.length);

        for (uint256 i = 0; i < _swaps.length; i++) {
            uint256 _slicedAmountIn = (_amount *
                _planDetail.tokenPercentages[i].percentage) / MAX_P;
            uint256 _amountOut;
            if (address(_tokenIn) == _planDetail.tokenPercentages[i].token) {
                _amountOut = _slicedAmountIn;
            } else {
                uint256 _balanceBefore = _swaps[i].token.uniBalanceOf(
                    address(this)
                );
                _swap(
                    _tokenIn,
                    _planDetail.tokenPercentages[i].token,
                    _slicedAmountIn,
                    _swaps[i].data
                );
                uint256 _balanceAfter = _swaps[i].token.uniBalanceOf(
                    address(this)
                );
                _amountOut = _balanceAfter - _balanceBefore;
            }

            IETFReceipt.TokenDetail memory _tokenDetail = IETFReceipt
                .TokenDetail({
                    token: address(_swaps[i].token),
                    amount: uint128(_amountOut),
                    price: _swaps[i].price
                });

            _tokenDetails[i] = _tokenDetail;
        }

        uint256 _investId = _ETFReceipt.mint(
            _userAddress,
            uint16(_planDetail.id),
            _tokenDetails
        );
        emit Invested(_userAddress, _investId, _planDetail.id, msg.sender);
    }

    /**
    * @notice Withdraws tokens from an investment, executing swaps if necessary.
    * @param _tokenId The ID of the token representing the investment.
    * @param _tokenOut The token to be withdrawn.
    * @param _percentage The percentage of the investment to be withdrawn.
    * @param _swaps An array of SwapInfo structures containing information about token swaps.
    * @dev Allows users to withdraw tokens from an investment, executing swaps if necessary
    *      to obtain the desired token for withdrawal. Validates the provided percentage and swap information,
    *      handles token transfers, fee deductions, and updates the investment accordingly. Emits a 'Withdrawn' event
    *      upon successful withdrawal.
    */
    function withdrawWithSwap(
        uint256 _tokenId,
        IERC20Upgradeable _tokenOut,
        uint16 _percentage,
        SwapInfo[] memory _swaps
    ) external nonReentrant {
        require(_tokenId < type(uint32).max, "ETFProxy: tokenId overflowed");
        _requiredValidPercentage(_percentage);

        IETFReceipt _ETFReceipt = IETFReceipt(ETFReceiptAddress);
        IETFReceipt.InvestDetail memory _invest = _ETFReceipt.tokenByTokenId(
            msg.sender,
            _tokenId
        );
        IETFReceipt.PlanDetail memory _planDetail = _ETFReceipt.planByPlanId(
            _invest.planId
        );

        _requiredValidSwapInfo(_swaps, _planDetail.tokenPercentages);

        uint256 totalAmountBefore = _tokenOut.uniBalanceOf(address(this));

        IETFReceipt.TokenDetail[] memory _remainsTokenDetails;
        uint256 _additionalAmount;
        (_remainsTokenDetails, _additionalAmount) = _batchWithdrawSwap(
            _tokenOut,
            _percentage,
            _swaps,
            _invest
        );

        uint256 _totalAmountOut = _tokenOut.uniBalanceOf(address(this));
        _totalAmountOut =
            _totalAmountOut -
            totalAmountBefore +
            _additionalAmount;

        _totalAmountOut = _deductFee(
            feeInfo.withdrawFee,
            _tokenOut,
            _totalAmountOut
        );
        _transferTokenTo(_tokenOut, payable(msg.sender), _totalAmountOut);

        if (_percentage != MAX_P) {
            _ETFReceipt.burnAndMint(
                uint32(_tokenId),
                msg.sender,
                _invest.planId,
                _remainsTokenDetails
            );
        } else {
            _ETFReceipt.burn(_tokenId);
        }
        emit Withdrawn(msg.sender, _tokenId, _planDetail.id);
    }

    /**
    * @notice Withdraws tokens from an investment without executing swaps.
    * @param _tokenId The ID of the token representing the investment.
    * @param _percentage The percentage of the investment to be withdrawn.
    * @dev Allows users to withdraw tokens from an investment without executing swaps.
    *      Validates the provided percentage, handles token transfers, fee deductions,
    *      and updates the investment accordingly. Emits a 'Withdrawn' event upon successful withdrawal.
    */
    function withdrawWithoutSwap(
        uint256 _tokenId,
        uint16 _percentage
    ) external nonReentrant whenNotPaused {
        require(_tokenId < type(uint32).max, "ETFProxy: tokenId overflowed");
        _requiredValidPercentage(_percentage);
        IETFReceipt _ETFReceipt = IETFReceipt(ETFReceiptAddress);
        IETFReceipt.InvestDetail memory _invest = _ETFReceipt.tokenByTokenId(
            msg.sender,
            _tokenId
        );

        IETFReceipt.TokenDetail[]
            memory _tokenDetails = new IETFReceipt.TokenDetail[](
                _invest.tokenDetails.length
            );

        for (uint i = 0; i < _invest.tokenDetails.length; i++) {
            address _token = _invest.tokenDetails[i].token;
            uint256 _amount = _invest.tokenDetails[i].amount;
            uint64 _price = _invest.tokenDetails[i].price;

            uint256 _beforeAmount = IERC20Upgradeable(_token).uniBalanceOf(
                address(this)
            );
            //Decrease fee
            uint256 _feePercentage = feeInfo.withdrawFee;
            uint256 _amountOut = (_amount * _percentage) / MAX_P;
            _amountOut = _deductFee(
                _feePercentage,
                IERC20Upgradeable(_token),
                _amountOut
            );

            IERC20Upgradeable(_token).uniTransfer(
                payable(msg.sender),
                _amountOut
            );
            uint256 _afterAmount = IERC20Upgradeable(_token).uniBalanceOf(
                address(this)
            );
            uint256 _transferredAmount = _beforeAmount - _afterAmount;
            uint256 _remainsAmount = _amount - _transferredAmount;

            if (_percentage != MAX_P) {
                IETFReceipt.TokenDetail memory _tokenDetail = IETFReceipt
                    .TokenDetail({
                        token: _token,
                        amount: uint128(_remainsAmount),
                        price: _price
                    });

                _tokenDetails[i] = _tokenDetail;
            }
        }

        if (_percentage != MAX_P) {
            _ETFReceipt.burnAndMint(
                uint32(_tokenId),
                msg.sender,
                _invest.planId,
                _tokenDetails
            );
        } else {
            _ETFReceipt.burn(_tokenId);
        }

        emit Withdrawn(msg.sender, _tokenId, _invest.planId);
    }

    /**
     * @notice Sets the address of the ETFReceipt contract.
     * @param _ETFReceiptAddress The address of the ETFReceipt contract.
     * @dev Allows the owner of the contract to update the address of the ETFReceipt contract.
     */
    function setETFReceiptAddress(
        address _ETFReceiptAddress
    ) external onlyOwner {
        _requiredValidAddress(_ETFReceiptAddress);
        ETFReceiptAddress = _ETFReceiptAddress;
        emit SetETFReceiptAddress(_ETFReceiptAddress);
    }

    /**
    * @notice Sets the address of the swap contract.
    * @param _swapContract The address of the swap contract.
    * @dev Allows the owner of the contract to update the address of the swap contract.
    */
    function setSwapContract(address _swapContract) external onlyOwner {
        swapContract = _swapContract;
        emit SetSwapContract(_swapContract);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
    * @notice Sets the fee configuration for the contract.
    * @param _feeInfo A FeeInfo structure containing the fee configuration details.
    * @dev Allows the owner of the contract to set the fee configuration when the contract is paused.
    *      Emits a 'SetFee' event upon successful fee configuration update.
    */
    function setFee(FeeInfo memory _feeInfo) public onlyOwner whenPaused {
        _setFee(_feeInfo);
        emit SetFee(msg.sender, _feeInfo.feeTo, _feeInfo.investFee, _feeInfo.withdrawFee);
    }

    /**
    * @notice Deducts fees from a given amount of tokens.
    * @param _percentage The fee percentage to be deducted.
    * @param _token The token from which the fee will be deducted.
    * @param _amount The amount of tokens from which the fee will be deducted.
    * @return _amountAfterFee The amount of tokens after deducting the fee.
    * @dev Internal function to deduct fees from a given amount of tokens based on a percentage.
    *      Transfers the deducted fee to the specified fee recipient.
    *      Emits a 'FeeDeducted' event upon successful fee deduction.
    */
    function _deductFee(
        uint256 _percentage,
        IERC20Upgradeable _token,
        uint256 _amount
    ) internal returns (uint256 _amountAfterFee) {
        uint256 _totalFee = _calculateFee(_amount, _percentage);
        _amountAfterFee = _amount - _totalFee;

        require(
            _percentage == 0 || _totalFee != 0,
            "ETFProxy: Fee is zero (amount is too low)"
        );

        if (_totalFee != 0) {
            _transferTokenTo(_token, feeInfo.feeTo, _totalFee);
            emit FeeDeducted(msg.sender, address(_token), _amount, _totalFee);
        }
    }

    /**
    * @notice Calculates the fee amount based on the given percentage.
    * @param _amount The total amount from which the fee is calculated.
    * @param _percentage The fee percentage to be applied.
    * @return The calculated fee amount.
    * @dev Internal function to calculate the fee amount based on the given percentage.
    *      The fee is calculated as a proportion of the total amount, expressed as a fraction of 1e20.
    */
    function _calculateFee(
        uint256 _amount,
        uint256 _percentage
    ) internal pure returns (uint256) {
        return (_amount * _percentage) / MAX_FEE;
    }

    /**
    * @notice Transfers tokens to a specified recipient address.
    * @param _token The ERC20 token contract.
    * @param _to The recipient address to which tokens will be transferred.
    * @param _amount The amount of tokens to transfer.
    * @dev Internal function to transfer tokens from the contract to the specified recipient address.
    *      Checks the balance before and after the transfer to ensure the correct amount was transferred.
    *      Reverts if the token transfer fails or if the transferred amount does not match the specified amount.
    */
    function _transferTokenTo(
        IERC20Upgradeable _token,
        address payable _to,
        uint256 _amount
    ) internal {
        // Check balance before and after the transfer
        uint256 _initialBalance = _token.uniBalanceOf(_to);
        _token.uniTransfer(_to, _amount);
        uint256 _finalBalance = _token.uniBalanceOf(_to);
        require(
            _finalBalance - _initialBalance == _amount,
            "ETFProxy: Token transfer failed"
        );
        if (_token.isETH()) {
            emit coinTransfer(address(this), _to, _amount);
        }
    }

    /**
     * @notice Transfers tokens to a specified recipient.
     * @param _token The token to be transferred.
     * @param _to The address of the recipient to whom tokens will be transferred.
     * @param _amount The amount of tokens to be transferred.
     * @dev Internal function to transfer tokens to a specified recipient.
     *      Checks the balance before and after the transfer to ensure it's successful.
     *      Reverts if the token transfer fails.
     */
    function _transferTokenFromTo(
        IERC20Upgradeable _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        // Check balance before and after the transfer
        uint256 _initialBalance = _token.uniBalanceOf(_to);
        _token.safeTransferFrom(_from, _to, _amount);
        uint256 _finalBalance = _token.uniBalanceOf(_to);
        require(
            _finalBalance - _initialBalance == _amount,
            "ETFProxy: Token transfer failed"
        );
    }

    /**
    * @notice Requires a valid address.
    * @param _address The address to be validated.
    * @dev Internal function to ensure that the provided address is not the zero address.
    *      Reverts with an error message if the provided address is not valid.
    */
    function _requiredValidAddress(address _address) internal pure {
        require(_address != address(0), "ETFProxy: address is not valid");
    }

    /**
    * @notice Requires a valid fee percentage.
    * @param _fee The fee percentage to be validated.
    * @dev Internal function to ensure that the provided fee percentage is within valid bounds.
    *      Verifies that the fee percentage is less than MAX_FEE.
    *      Reverts if the provided fee percentage is invalid.
    */
    function _requiredValidFee(uint256 _fee) internal pure {
        // 1e18 is 1%
        require(_fee < MAX_FEE, "ETFProxy: Invalid fee");
    }

    /**
    * @notice Sets the fee information.
    * @param _feeInfo The FeeInfo structure containing fee-related details.
    * @dev Internal function to set the fee information.
    *      Ensures that the fee recipient address and fee percentages are valid.
    *      Updates the feeInfo state variable with the provided fee information.
    *      Emits a 'SetFee' event with the updated fee details.
    */
    function _setFee(FeeInfo memory _feeInfo) internal {
        _requiredValidAddress(_feeInfo.feeTo);
        _requiredValidFee(_feeInfo.investFee);
        _requiredValidFee(_feeInfo.withdrawFee);

        feeInfo = _feeInfo;
        emit SetFee(
            msg.sender,
            _feeInfo.feeTo,
            _feeInfo.investFee,
            _feeInfo.withdrawFee
        );
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
    * @notice Executes a token swap.
    * @param _fromToken The token to be swapped from.
    * @param _toToken The token to be swapped to.
    * @param _amount The amount of tokens to be swapped.
    * @param _data Additional data required for the swap.
    * @return The amount of tokens received after the swap.
    * @dev Internal function to execute a token swap.
    *      Validates the swap data, approves token transfer if needed, and executes the swap.
    *      Returns the amount of tokens received after the swap.
    */
    function _swap(
        IERC20Upgradeable _fromToken,
        address _toToken,
        uint256 _amount,
        bytes memory _data
    ) private returns (uint256) {
        _validateSwapData(
            address(_fromToken),
            _toToken,
            address(this),
            _amount,
            _data
        );

        address _swapContract = swapContract; //gas saving
        if (!_fromToken.isETH()) {
            _fromToken.uniApprove(_swapContract, _amount);
        }
        bytes memory returnData = AddressUpgradeable.functionCallWithValue(
            _swapContract,
            _data,
            _fromToken.isETH() ? _amount : 0
        );

        return abi.decode(returnData, (uint256));
    }

    /**
    * @notice Executes batch withdrawals with swaps.
    * @param _tokenOut The token to be withdrawn.
    * @param _percentage The percentage of the investment to be withdrawn.
    * @param _swaps An array of SwapInfo structures containing information about token swaps.
    * @param _invest An InvestDetail structure representing the investment details.
    * @return _tokenDetails An array of TokenDetail structures containing details of remaining tokens after withdrawal.
    * @return _additionalAmount The additional amount if tokenOut is eq to an invest token (in this case the amount will not swap and remains in the contract).
    * @dev Internal function to execute batch withdrawals with swaps.
    *      Calculates the amounts to be swapped and executed swaps accordingly.
    *      Returns the remaining token details after withdrawal and the additional amount of tokens received after swaps.
    */
    function _batchWithdrawSwap(
        IERC20Upgradeable _tokenOut,
        uint16 _percentage,
        SwapInfo[] memory _swaps,
        IETFReceipt.InvestDetail memory _invest
    ) private returns (IETFReceipt.TokenDetail[] memory, uint256) {
        uint256 _additionalAmount;
        IETFReceipt.TokenDetail[]
            memory _tokenDetails = new IETFReceipt.TokenDetail[](
                _invest.tokenDetails.length
            );
        for (uint i = 0; i < _invest.tokenDetails.length; i++) {
            uint256 _slicedAmountIn = (_invest.tokenDetails[i].amount *
                _percentage) / MAX_P;
            uint256 _amountOut;
            if (address(_tokenOut) == _invest.tokenDetails[i].token) {
                _amountOut = _slicedAmountIn;
                _additionalAmount = _slicedAmountIn;
            } else {
                uint256 _beforeAmount = IERC20Upgradeable(
                    _invest.tokenDetails[i].token
                ).uniBalanceOf(address(this));
                _swap(
                    IERC20Upgradeable(_invest.tokenDetails[i].token),
                    address(_tokenOut),
                    _slicedAmountIn,
                    _swaps[i].data
                );
                uint256 _afterAmount = IERC20Upgradeable(
                    _invest.tokenDetails[i].token
                ).uniBalanceOf(address(this));

                _amountOut = _beforeAmount - _afterAmount;
            }

            uint256 _remainsAmount = _invest.tokenDetails[i].amount -
                _amountOut;

            if (_percentage != MAX_P) {
                IETFReceipt.TokenDetail memory _tokenDetail = IETFReceipt
                    .TokenDetail({
                        token: _invest.tokenDetails[i].token,
                        amount: uint128(_remainsAmount),
                        price: uint16(_invest.tokenDetails[i].price)
                    });

                _tokenDetails[i] = _tokenDetail;
            }
        }
        return (_tokenDetails, _additionalAmount);
    }

    /**
    * @notice Validates swap data to ensure correctness.
    * @param _fromToken The token from which the swap is initiated.
    * @param _toToken The token to which the swap is made.
    * @param _receiver The receiver address specified in the swap data.
    * @param _amount The amount specified in the swap data.
    * @param _data The swap data containing encoded parameters.
    * @dev Internal function to validate swap data and ensure correctness.
    *      Decodes the parameters from the provided swap data and compares them with the input parameters.
    *      Reverts if any parameter in the swap data is invalid or does not match with the input parameters.
    */
    function _validateSwapData(
        address _fromToken,
        address _toToken,
        address _receiver,
        uint256 _amount,
        bytes memory _data
    ) private pure {
        bytes4 _sig;

        address _decodedFromToken;
        address _decodedToToken;
        address _decodedReceiver;
        uint256 _decodedAmountIn;

        // Decode the parameters
        assembly {
            _sig := mload(add(_data, 32))
            _decodedFromToken := mload(add(_data, 36)) // Offset for the first address parameter
            _decodedToToken := mload(add(_data, 68)) // Offset for the second address parameter
            _decodedReceiver := mload(add(_data, 100)) // Offset for the third address parameter
            _decodedAmountIn := mload(add(_data, 132)) // Offset for the uint256 parameter
        }

        require(_sig == 0x796ecb0d, "ETFProxy: Swap signature is not correct");

        require(
            _decodedFromToken == _fromToken,
            "ETFProxy: fromToken is invalid in swap data"
        );
        require(
            _decodedToToken == _toToken,
            "ETFProxy: toToken is invalid in swap data"
        );
        require(
            _decodedReceiver == _receiver,
            "ETFProxy: receiver is invalid in swap data"
        );
        require(
            _decodedAmountIn == _amount,
            "ETFProxy: amount is invalid in swap data"
        );
    }

    /**
    * @notice Requires valid swap information.
    * @param _swaps An array of SwapInfo structures containing information about token swaps.
    * @param _tokenPercentages An array of TokenPercentage structures representing token percentages.
    * @dev Internal function to ensure that the provided swap information is valid.
    *      Compares the lengths of the provided arrays and verifies that each swap token matches the corresponding token percentage.
    *      Reverts if the lengths mismatch or if any swap information is invalid.
    */
    function _requiredValidSwapInfo(
        SwapInfo[] memory _swaps,
        IETFReceipt.TokenPercentage[] memory _tokenPercentages
    ) private pure {
        require(
            _swaps.length == _tokenPercentages.length,
            "ETFProxy: SwapInfo mismatch length"
        );
        for (uint256 i = 0; i < _tokenPercentages.length; i++) {
            require(
                address(_swaps[i].token) == _tokenPercentages[i].token,
                "ETFProxy: SwapInfo is invalid"
            );
        }
    }

    /**
    * @notice Requires a valid percentage value.
    * @param _percentage The percentage value to be validated.
    * @dev Internal function to ensure that the provided percentage value is within valid bounds.
    *      Verifies that the percentage is within the range of 500 (5%) to MAX_P (10000, 100%).
    *      Reverts if the provided percentage is invalid.
    */
    function _requiredValidPercentage(uint16 _percentage) private pure {
        require(
            _percentage <= MAX_P && _percentage >= 500,
            "ETFProxy: Percentage is invalid"
        );
    }
}
