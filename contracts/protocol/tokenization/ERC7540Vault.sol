// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
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
        require(_asset != address(0), "ERC7540Vault/invalid-asset");
        require(_share != address(0), "ERC7540Vault/invalid-share");
        require(_aavePool != address(0), "ERC7540Vault/invalid-pool");
        require(_poolManager != address(0), "ERC7540Vault/invalid-manager");
        
        share = _share;
        aavePool = _aavePool;
        poolManager = _poolManager;
        
        // Get aToken address and validate
        address aToken = IPool(_aavePool).getReserveData(_asset).aTokenAddress;
        require(aToken != address(0), "ERC7540Vault/invalid-atoken");
        
        // Set approvals during initialization
        require(IERC20(_asset).approve(_aavePool, type(uint256).max), "ERC7540Vault/approve-failed");
        require(IERC20(aToken).approve(_aavePool, type(uint256).max), "ERC7540Vault/approve-failed");
    }
    
    // --- ERC-7540 methods ---
    function setOperator(address operator, bool approved) public virtual returns (bool) {
        Validation.validateSetOperator(operator);
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return approved;
    }

    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId) {
        Validation.validateController(controller, owner, isOperator);
        Validation.validateRequestDeposit(address(this), owner, assets);
        IERC20(asset()).transferFrom(owner, address(this), assets);
        userVaultData[owner].pendingDepositRequest += assets.toUint128();
        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    function fulfillDepositRequest(uint256 assets, address receiver) external onlyPoolManager returns (uint256 requestId) {
        Validation.validateFulfillDepositRequest(userVaultData[receiver]);
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        uint256 shares = assets.rayDiv(index);
        userVaultData[receiver].maxMint += shares.toUint128();
        uint128 newPendingDepositRequest = userVaultData[receiver].pendingDepositRequest >= assets.toUint128() ? userVaultData[receiver].pendingDepositRequest - assets.toUint128() : 0;
        userVaultData[receiver].pendingDepositRequest = newPendingDepositRequest;
            userVaultData[receiver].pendingDepositRequest > assets.toUint128() ? userVaultData[receiver].pendingDepositRequest - assets.toUint128() : 0;
        
        if (userVaultData[receiver].pendingDepositRequest == 0) delete userVaultData[receiver].pendingDepositRequest;

        IPool(aavePool).supply(asset(), assets, address(this), 0);
        ISToken sToken = ISToken(share); 
        sToken.mint(msg.sender, address(this), assets, index);
        emit DepositClaimable(receiver, REQUEST_ID, assets, shares);
        return REQUEST_ID;
    }
    
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        Validation.validateController(controller, receiver, isOperator);
        IERC20(share).transferFrom(address(this), receiver, shares);
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        return shares.rayDiv(index);
    }

    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares) {
        Validation.validateController(controller, receiver, isOperator);
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        shares = assets.rayDiv(index);
        require(userVaultData[receiver].maxMint >= shares, "ERC7540Vault/insufficient-mint-allowance");
        
        userVaultData[receiver].maxMint = userVaultData[receiver].maxMint - shares.toUint128();
        ISToken(share).transfer(receiver, shares);  // Transfer sTokens from vault to user
        
        emit Deposit(controller, receiver, shares.rayDiv(index), shares);
        return shares;
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
        Validation.validateController(controller, owner, isOperator);
        Validation.validateRequestRedeem(share, shares, owner);
        ISToken sToken = ISToken(share);
        sToken.transferFrom(owner, address(this), shares);
        userVaultData[owner].pendingRedeemRequest += shares.toUint128();
        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function fulfillRedeemRequest(
        uint256 shares,
        address receiver
    ) external onlyPoolManager returns (uint256 requestId) {
        Validation.validateFulfillRedeemRequest(userVaultData[receiver]);
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        uint256 assets = shares.rayMul(index);
        userVaultData[receiver].maxWithdraw = userVaultData[receiver].maxWithdraw + assets.toUint128();
        userVaultData[receiver].pendingRedeemRequest = 
            userVaultData[receiver].pendingRedeemRequest > shares ? userVaultData[receiver].pendingRedeemRequest - shares.toUint128() : 0;
        
        if (userVaultData[receiver].pendingRedeemRequest == 0) delete userVaultData[receiver].pendingRedeemRequest;

        ISToken sToken = ISToken(share);
        sToken.burn(address(this), receiver, assets, index);
        emit RedeemClaimable(receiver, REQUEST_ID, assets, shares);
        return REQUEST_ID;
    }

    function redeem(uint256 assets, address controller, address owner) 
        public 
        override(ERC4626Upgradeable, IERC7540Vault) 
        returns (uint256 shares)
    {
        Validation.validateController(controller, owner, isOperator);
        Validation.validateRedeem(userVaultData[owner], shares);
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        userVaultData[owner].maxWithdraw = 
            userVaultData[owner].maxWithdraw > shares ? userVaultData[owner].maxWithdraw - shares.toUint128() : 0;
        
        shares = assets.rayDiv(index);  // Calculate shares first
        
        IPool(aavePool).withdraw(asset(), assets, owner);
        
        emit Withdraw(address(this), controller, owner, assets, shares);
        return shares;
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256) {
        return userVaultData[controller].pendingRedeemRequest;
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256) {
        return userVaultData[controller].maxWithdraw;
    }

    function getShare() external view returns (address) {
        return share;
    }

    function getUserVaultData(address user) external view returns (Types.UserVaultData memory) {
        return userVaultData[user];
    }

    function convertToShares(uint256 assets) 
        public 
        view 
        override(ERC4626Upgradeable, IERC7540Vault) 
        returns (uint256) 
    {
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        return assets.rayDiv(index);
    }

    function convertToAssets(uint256 shares) 
        public 
        view 
        override(ERC4626Upgradeable, IERC7540Vault) 
        returns (uint256) 
    {
        uint256 index = IPool(aavePool).getReserveData(asset()).liquidityIndex;
        return shares.rayMul(index);
    }
}
