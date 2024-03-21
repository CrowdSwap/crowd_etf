// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../helpers/OwnableUpgradeable.sol";
import "./IETFReceipt.sol";

contract ETFReceipt is
    Initializable,
    UUPSUpgradeable,
    ERC721EnumerableUpgradeable,
    IETFReceipt,
    OwnableUpgradeable
{
    struct InvestDetails {
        uint256 amount;
        uint256 price;
    }

    uint16 public constant MAX_P = 1e4;
    address private ETFProxyAddress;

    // Array with all token ids, used for enumeration

    // Invest[] private receipts;
    // mapping(uint256 => TokenDetail[]) private tokenDetails;

    Plan[] public plans;
    mapping(uint256 => TokenPercentage[]) public planTokenPercentages;

    bytes[] private receipts2;

    event PlanCreated(
        address indexed operator,
        uint256 indexed planId,
        uint256 tokenLength
    );

    event PlanUpdated(
        address indexed operator,
        uint256 indexed planId,
        bool isActive,
        string name
    );

    event Minted(address indexed to, uint256 indexed tokenId);

    event Burned(uint256 indexed tokenId);

    event BurnedAndMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed newId
    );

    modifier onlyETF() {
        require(msg.sender == ETFProxyAddress, "ETFReceipt: Invalid caller");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev The contract constructor

     */
    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        ERC721Upgradeable.__ERC721_init(name, symbol);
        OwnableUpgradeable.initialize();
    }

    /**
     * @notice Create a new plan with the specified name and token percentages.
     *         Only callable by the contract owner.
     * @dev This function creates a new plan with the provided name and token percentages.
     * @param _name The name of the plan.
     * @param _tokenPercentages An array of TokenPercentage structures representing the
     *                          percentage distribution of tokens for the plan.
     */
    function createPlan(
        string memory _name,
        TokenPercentage[] memory _tokenPercentages
    ) external onlyOwner {
        _requiredValidTokenPercentages(_tokenPercentages);

        Plan memory _plan = Plan(_name, true);
        plans.push(_plan);

        uint256 _planId = plans.length - 1;

        for (uint256 i = 0; i < _tokenPercentages.length; i++) {
            planTokenPercentages[_planId].push(_tokenPercentages[i]);
        }
        emit PlanCreated(msg.sender, _planId, _tokenPercentages.length);
    }

    /**
     * @notice To activate/deactivate an existing plan
     * @param _planId The id of specific plan
     * @param _name The new name of the plan.
     * @param _isActive The new status of the plan
     */
    function changePlanActiveStatus(
        uint256 _planId,
        string memory _name,
        bool _isActive
    ) external onlyOwner {
        require(_planId < plans.length, "ETFReceipt: Invalid plan ID");

        // Update the plan attributes
        plans[_planId].active = _isActive;
        plans[_planId].name = _name;

        emit PlanUpdated(msg.sender, _planId, _isActive, _name);
    }

    function setETFProxyAddress(address _ETFProxyAddress) external onlyOwner {
        ETFProxyAddress = _ETFProxyAddress;
    }

    /**
     * @return Returns all plans
     */
    function getAllPlans() external view returns (PlanDetail[] memory) {
        uint256 _planCounter = plans.length; //gas saving
        PlanDetail[] memory _allPlansArray = new PlanDetail[](_planCounter);

        for (uint256 i = 0; i < _planCounter; ++i) {
            _allPlansArray[i] = PlanDetail({
                id: i,
                name: plans[i].name,
                active: plans[i].active,
                tokenPercentages: planTokenPercentages[i]
            });
        }

        return _allPlansArray;
    }

    /**
     * @notice Get the investment details for tokens owned by a specific address.
     * @dev This function retrieves investment details for tokens owned by the specified address.
     * @param _owner The address of the token owner.
     * @return An array of InvestDetail structures representing the investment details
     *         for tokens owned by the specified address.
     */
    function getTokensByOwner(
        address _owner
    ) external view returns (InvestDetail[] memory) {
        uint256 balance = balanceOf(_owner);
        InvestDetail[] memory investDetails = new InvestDetail[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 _tokenId = tokenOfOwnerByIndex(_owner, i);

            // InvestDetail memory _investDetail = InvestDetail({
            //     id: receipts[_tokenId].id,
            //     planId: receipts[_tokenId].planId,
            //     createTime: receipts[_tokenId].createTime,
            //     tokenDetails: tokenDetails[receipts[_tokenId].id]
            // });

            InvestDetail memory _investDetail = bytesToStruct(
                receipts2[_tokenId]
            );

            investDetails[i] = _investDetail;
        }

        return investDetails;
    }

    /**
     * @notice Get the investment details for a specific token ID owned by a particular address.
     * @dev This function retrieves investment details for the token with the specified ID,
     *      owned by the given address.
     * @param _userAddress The address of the user who owns the token.
     * @param _tokenId The ID of the token for which investment details are being queried.
     * @return An InvestDetail structure representing the investment details for the specified token.
     * @dev Reverts if the specified address is not the owner of the token.
     */
    function tokenByTokenId(
        address _userAddress,
        uint256 _tokenId
    ) external view returns (InvestDetail memory) {
        address _owner = ownerOf(_tokenId);
        require(
            _owner == _userAddress,
            "ETFReceipt: The user is not owner of this token"
        );

        // InvestDetail memory _investDetail = InvestDetail({
        //     id: receipts[_tokenId].id,
        //     planId: receipts[_tokenId].planId,
        //     createTime: receipts[_tokenId].createTime,
        //     tokenDetails: tokenDetails[receipts[_tokenId].id]
        // });

        InvestDetail memory _investDetail = bytesToStruct(receipts2[_tokenId]);

        return _investDetail;
    }

    /**
     * @notice Get the details of a specific investment plan by its ID.
     * @dev This function retrieves the details of the investment plan with the specified ID.
     * @param _planId The ID of the investment plan.
     * @return A PlanDetail structure containing the details of the specified investment plan.
     * @dev Reverts if the specified plan ID is invalid.
     */
    function planByPlanId(
        uint256 _planId
    ) external view returns (PlanDetail memory) {
        require(_planId < plans.length, "ETFReceipt: Invalid plan ID");
        Plan memory _plan = plans[_planId];
        PlanDetail memory _planDetail = PlanDetail({
            id: _planId,
            name: _plan.name,
            active: _plan.active,
            tokenPercentages: planTokenPercentages[_planId]
        });
        return _planDetail;
    }

    /**
     * @notice Mint new tokens for a specified address according to a given investment plan.
     * @dev This function mints new tokens for the specified address, corresponding to the
     *      investment plan identified by _planId, with the provided token details.
     * @param _to The address to which the new tokens will be minted.
     * @param _planId The ID of the investment plan for which tokens are being minted.
     * @param _tokenDetails An array of TokenDetail structures containing details about the
     *                      tokens being minted.
     * @return The ID of the newly minted tokens.
     * @dev Only callable by the ETF contract.
     */
    function mint(
        address _to,
        uint16 _planId,
        TokenDetail[] memory _tokenDetails
    ) public onlyETF returns (uint256) {
        uint32 _id = uint32(receipts2.length);
        InvestDetail memory _newInvest = InvestDetail({
            id: _id,
            planId: _planId,
            createTime: uint32(block.timestamp),
            tokenDetails: _tokenDetails
        });

        bytes memory a = structToBytes(_newInvest);

        receipts2.push(a);

        // receipts.push(_newInvest);
        // for (uint256 i = 0; i < _tokenDetails.length; i++) {
        //     tokenDetails[_id].push(_tokenDetails[i]);
        // }
        _mint(_to, _id);
        emit Minted(_to, _id);
        return _id;
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function burn(uint256 _tokenId) public onlyETF {
        address owner = ERC721Upgradeable.ownerOf(_tokenId);
        require(
            isApprovedForAll(owner, ETFProxyAddress) ||
                getApproved(_tokenId) == ETFProxyAddress,
            "ETFReceipt: approve needed"
        );
        _burn(_tokenId);
        emit Burned(_tokenId);
    }

    /**
     * @notice Burn an existing token and mint new tokens for a specified address according to a given investment plan.
     * @dev This function burns the existing token with the specified ID, and then mints new tokens for the specified address,
     *      corresponding to the investment plan identified by _planId, with the provided token details.
     * @param _tokenId The ID of the token to be burned.
     * @param _to The address to which the new tokens will be minted.
     * @param _planId The ID of the investment plan for which tokens are being minted.
     * @param _tokenDetails An array of TokenDetail structures containing details about the
     *                      tokens being minted.
     * @dev Only callable by the ETFProxy contract.
     * @dev Requires the sender to be approved to manage the existing token or the owner of the existing token.
     */
    function burnAndMint(
        uint32 _tokenId,
        address _to,
        uint16 _planId,
        TokenDetail[] memory _tokenDetails
    ) public onlyETF {
        address _owner = ERC721Upgradeable.ownerOf(_tokenId);
        require(
            isApprovedForAll(_owner, ETFProxyAddress) ||
                getApproved(_tokenId) == ETFProxyAddress,
            "ETFReceipt: approve needed"
        );
        _burn(_tokenId);

        uint32 _newId = uint32(receipts2.length);
        InvestDetail memory _newInvest = InvestDetail({
            id: _newId,
            planId: _planId,
            createTime: uint32(block.timestamp),
            tokenDetails: _tokenDetails
        });

        bytes memory a = structToBytes(_newInvest);

        receipts2.push(a);

        // receipts.push(_newInvest);
        // for (uint256 i = 0; i < _tokenDetails.length; i++) {
        //     tokenDetails[_newId].push(_tokenDetails[i]);
        // }

        _mint(_to, _newId);
        emit BurnedAndMinted(_tokenId, _to, _newId);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Internal function to validate token percentages for a new plan.
     * @param _tokenPercentages An array of TokenPercentage structures representing the
     *                          percentage distribution of tokens for the plan.
     * @dev Ensures that each token address and percentage value are valid,
     *      and that the sum of percentages equals MAX_P.
     */
    function _requiredValidTokenPercentages(
        TokenPercentage[] memory _tokenPercentages
    ) private pure {
        uint16 count;
        for (uint256 i = 0; i < _tokenPercentages.length; i++) {
            require(
                _tokenPercentages[i].token != address(0),
                "ETFReceipt: one of the addresses is invalid"
            );
            require(
                _tokenPercentages[i].percentage != 0,
                "ETFReceipt: one of the percentages is invalid"
            );
            count += _tokenPercentages[i].percentage;
        }
        require(
            count == MAX_P,
            "ETFReceipt: There is a miscalculation in plan percentages"
        );
    }

    function structToBytes(InvestDetail memory _struct) public pure returns (bytes memory) {
        uint32 len = uint32(_struct.tokenDetails.length);
        bytes memory result  = abi.encodePacked(_struct.id,_struct.planId,_struct.createTime,len);
        for(uint256 i=0; i < _struct.tokenDetails.length; i++){
            result = abi.encodePacked(result, _struct.tokenDetails[i].token, 
                _struct.tokenDetails[i].amount, _struct.tokenDetails[i].price);
        }
        return result;
    }

    function bytesToStruct(bytes memory data) public pure returns (InvestDetail memory) {
        uint256 size16 = 0x02;
        uint256 size32 = 0x04;
        uint256 size64 = 0x08;
        uint256 addressSize = 0x14;
        uint256 size128 = 0x10;
        
        uint256 dataPtr;
        InvestDetail memory investDetail;
        TokenDetail memory tokenDetail;

        uint32 _id;
        uint16 _planId;
        uint32 _createTime;
        uint32 len;

        assembly {
            // Load packedData into memory
            dataPtr := add(data, size32) // Skip the length of bytes (32 bytes)

            // Load the first uint32 value from packedData
            _id := mload(dataPtr)

            // Load the second uint32 value from packedData
            dataPtr := add(dataPtr, size16) // Move the pointer by 4 bytes
            _planId := mload(dataPtr)

            
            // Load the third uint32 value from packedData
            dataPtr := add(dataPtr, size32) // Move the pointer by 4 bytes
            _createTime := mload(dataPtr)

            
            dataPtr := add(dataPtr, size32) // Move the pointer by 4 bytes
            len := mload(dataPtr)
                      
        }

        TokenDetail[] memory _tokenDetails = new TokenDetail[](len);

            for(uint256 i=0; i < len;i++){
                assembly {                
                        // Load tokenDetails element fields
                        dataPtr := add(dataPtr, addressSize)
                        let token := mload(dataPtr)
                        dataPtr := add(dataPtr, size128)
                        let amount := mload(dataPtr)
                        dataPtr := add(dataPtr, size64)
                        let price := mload(dataPtr)

                        // Create TokenDetail struct instance
                        tokenDetail := mload(0x40)
                        mstore(tokenDetail, token)
                        mstore(add(tokenDetail, 32), amount)
                        mstore(add(tokenDetail, 64), price)

                        mstore(0x40, add(tokenDetail, 0x60))
                }
                _tokenDetails[i] = tokenDetail;
            }

            investDetail.id = _id;
            investDetail.planId = _planId;
            investDetail.createTime = _createTime;
            investDetail.tokenDetails = _tokenDetails;

            return investDetail;
        }
}
