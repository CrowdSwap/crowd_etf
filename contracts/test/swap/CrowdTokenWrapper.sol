// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../helpers/Ownable.sol";

contract CrowdTokenWrapper is ERC20, ERC20Burnable, Ownable, AccessControl {
    /**
     * @dev Creating MINTER_ROLE & BURNER_ROLE
     *
     * Create a new role identifier for the minter & burner roles.
     *
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(
        string memory tName,
        string memory tSymbol
    ) ERC20(tName, tSymbol) {
        /**
         * @dev Set Msg.sender as Admin for Role Base Access Routine
         *
         *
         * Grant the contract deployer the default admin role: it will be able to grant and revoke any roles
         */
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev mint new Tokens
     *
     * Check that the calling account has the minter role and mint new Tokens
     *
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev burn Tokens
     *
     * Check that the calling account has the burner role and burn an amount of Tokens
     *
     */
    function burn(uint256 amount) public override onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    /**
     * @dev burn Tokens
     *
     * Check that the calling account has the burner role and burn an amount of Tokens in a specific account
     *
     */
    function burnFrom(
        address account,
        uint256 amount
    ) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(account, amount);
    }

    /**
     * @dev Set Minter Role
     *
     * Set a new minter for the token
     *
     */
    function setMinter(address newMinter) public {
        grantRole(MINTER_ROLE, newMinter);
    }

    /**
     * @dev Set Burner Role
     *
     * Set a new burner for the token
     *
     */
    function setBurner(address newBurner) public {
        grantRole(BURNER_ROLE, newBurner);
    }

    /**
     * @dev Revoke Minter Role
     *
     *  Revoke an old Minter of the token
     *
     */
    function revokeMinter(address oldMinter) public {
        revokeRole(MINTER_ROLE, oldMinter);
    }

    /**
     * @dev Revoke Burner Role
     *
     * Revoke an old burner of the token
     *
     */
    function revokeBurner(address oldBurner) public {
        revokeRole(BURNER_ROLE, oldBurner);
    }

    /**
     * @dev Set Admin Role
     *
     * Set a new account as admin of token
     *
     */
    function setAdminRole(address newAdmin) public onlyOwner {
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
    }

    /**
     * @dev Revoke Admin Role
     *
     * Revoke an old admin of token
     *
     */
    function revokeAdminRole(address oldAdmin) public onlyOwner {
        revokeRole(DEFAULT_ADMIN_ROLE, oldAdmin);
    }
}
