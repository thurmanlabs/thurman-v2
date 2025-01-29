// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {ISToken} from "../../interfaces/ISToken.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Types} from "../libraries/types/Types.sol";
import {Validation} from "../libraries/services/Validation.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";


contract ERC7540Vault is ERC4626Upgradeable, IERC7540Vault {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    modifier onlyPoolManager() {
        require(msg.sender == poolManager, "ERC7540Vault/only-pool-manager");
        _;
    }

    mapping(address => mapping(address => bool)) public isOperator;
    /// @dev Requests for Thurman pool are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    address public poolManager;
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
        address _aavePool,
        address _poolManager
    ) external initializer {
        __ERC4626_init(IERC20(_asset));
        share = _share;
        aavePool = _aavePool;
        poolManager = _poolManager;
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

    function fulfillDepositRequest(uint256 assets, uint256 shares, address receiver) external onlyPoolManager returns (uint256 requestId) {
        Types.UserVaultData memory userVault = userVaultData[receiver];
        Validation.validateFulfillDepositRequest(userVault);
        userVault.maxMint = userVault.maxMint + shares.toUint128();
        userVault.pendingDepositRequest = 
            userVault.pendingDepositRequest > assets ? userVault.pendingDepositRequest - assets.toUint128() : 0;
        
        if (userVault.pendingDepositRequest == 0) delete userVault.pendingDepositRequest;

        ISToken sToken = ISToken(share);
        sToken.aaveSupply(assets, address(this));
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        sToken.mint(msg.sender, address(this), assets, index);
        emit DepositClaimable(receiver, REQUEST_ID, assets, shares);
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

    function requestRedeem(
        uint256 shares, 
        address controller, 
        address owner
    ) external returns (uint256 requestId) {
        Validation.validateController(controller, isOperator);
        Validation.validateRequestRedeem(share, shares);
        ISToken sToken = ISToken(share);
        sToken.transferFrom(owner, address(this), shares);
        userVaultData[owner].pendingRedeemRequest += shares.toUint128();
        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function fulfillRedeemRequest(
        uint256 shares, 
        uint256 assets, 
        address receiver
    ) external onlyPoolManager returns (uint256 requestId) {
        Types.UserVaultData memory userVault = userVaultData[receiver];
        Validation.validateFulfillRedeemRequest(userVault);
        userVault.maxWithdraw = userVault.maxWithdraw + assets.toUint128();
        userVault.pendingRedeemRequest = 
            userVault.pendingRedeemRequest > shares ? userVault.pendingRedeemRequest - shares.toUint128() : 0;
        
        if (userVault.pendingRedeemRequest == 0) delete userVault.pendingRedeemRequest;

        ISToken sToken = ISToken(share);
        sToken.aaveWithdraw(assets, address(this));
        sToken.burn(address(this), receiver, shares, 0);
        emit RedeemClaimable(receiver, REQUEST_ID, assets, shares);
        return REQUEST_ID;
    }

    function redeem(uint256 shares, address controller, address owner) 
        public 
        override(ERC4626Upgradeable, IERC7540Vault) 
        returns (uint256 assets)
    {
        Types.UserVaultData memory userVault = userVaultData[owner];
        Validation.validateController(controller, isOperator);
        Validation.validateRedeem(userVault, shares);
        userVault.maxWithdraw = userVault.maxWithdraw > shares ? userVault.maxWithdraw - shares.toUint128() : 0;
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        IERC20(asset()).transferFrom(owner, address(this), shares.rayDiv(index));
        return shares.rayDiv(index);
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256) {
        return userVaultData[controller].pendingRedeemRequest;
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256) {
        return userVaultData[controller].maxWithdraw;
    }
}