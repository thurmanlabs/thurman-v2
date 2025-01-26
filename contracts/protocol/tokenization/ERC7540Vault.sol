// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {Types} from "../libraries/types/Types.sol";
import {Validation} from "../libraries/services/Validation.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";


contract ERC7540Vault is Initializable, UUPSUpgradeable, OwnableUpgradeable, IERC7540Vault {
    mapping(address => mapping(address => bool)) public isOperator;
    /// @dev Requests for Thurman pool are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    address public asset;
    address public share;
    mapping(address => Types.UserVaultData) public userVaultData;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _asset,
        address _share
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        asset = _asset;
        share = _share;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // --- ERC-7540 methods ---
    function setOperator(address operator, bool approved) public virtual returns (bool) {
        Validation.validateSetOperator(operator);
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return approved;
    }

    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId) {
        Validation.validateController(controller, isOperator);
        Validation.validateRequestDeposit(address(this), assets);
        IERC20(asset).transferFrom(msg.sender, share, assets);
        userVaultData[owner].pendingDepositRequest += SafeCast.toUint128(assets);
        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }
    
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        Validation.validateController(controller, isOperator);
        IERC20(share).transferFrom(address(this), receiver, shares);
        // TODO: Implement calculation of assets
        return shares;
    }

    function pendingDepositRequest(address owner) external view returns (uint256) {
        return userVaultData[owner].pendingDepositRequest;
    }

    function claimableDepositRequest(address owner) external view returns (uint256) {
        return userVaultData[owner].maxMint;
    }
}
