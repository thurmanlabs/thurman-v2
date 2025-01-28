// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Types} from "../libraries/types/Types.sol";
import {Validation} from "../libraries/services/Validation.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";


contract ERC7540Vault is ERC4626Upgradeable, IERC7540Vault {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    mapping(address => mapping(address => bool)) public isOperator;
    /// @dev Requests for Thurman pool are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    address public aavePool;
    address public share;
    mapping(address => Types.UserVaultData) public userVaultData;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _asset,
        address _share,
        address _aavePool
    ) external initializer {
        __ERC4626_init(IERC20(_asset));
        share = _share;
        aavePool = _aavePool;
    }
    
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
        IERC20(asset()).transferFrom(msg.sender, share, assets);
        userVaultData[owner].pendingDepositRequest += assets.toUint128();
        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }
    
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        Validation.validateController(controller, isOperator);
        IERC20(share).transferFrom(address(this), receiver, shares);
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        return shares.rayDiv(index);
    }

    function deposit(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        Validation.validateController(controller, isOperator);
        IERC20(share).transferFrom(address(this), receiver, shares);
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        return shares.rayDiv(index);
    }

    function pendingDepositRequest(uint256, address controller) external view returns (uint256) {
        return userVaultData[controller].pendingDepositRequest;
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256) {
        return userVaultData[controller].maxMint;
    }
}
