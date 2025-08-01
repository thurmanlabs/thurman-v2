// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPoolManager} from "../../interfaces/IPoolManager.sol";
import {ILoanManager} from "../../interfaces/ILoanManager.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {ISToken} from "../../interfaces/ISToken.sol";
import {IDToken} from "../../interfaces/IDToken.sol";
import {Types} from "../libraries/types/Types.sol";
import {Validation} from "../libraries/services/Validation.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {MathUtils} from "../libraries/math/MathUtils.sol";
import {LoanMath} from "../libraries/math/LoanMath.sol";

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
    uint256 public nextLoanId;

    address public poolManager;
    uint16 public poolId;
    address public loanManager;
    address public share;
    address public dToken;
    uint8 public assetDecimals;
    mapping(address => Types.UserVaultData) public userVaultData;
    mapping(address => Types.Loan[]) public loans;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    address private _asset;

    function initialize(
        address _assetAddress,
        address _share,
        address _dToken,
        address _poolManager,
        address _loanManager
    ) external initializer {
        __ERC20_init("ERC7540Vault", "ERC7540");
        __ERC4626_init(IERC20(_assetAddress));
        require(_assetAddress != address(0), "ERC7540Vault/invalid-asset");
        require(_share != address(0), "ERC7540Vault/invalid-share");
        require(_dToken != address(0), "ERC7540Vault/invalid-dToken");
        require(_poolManager != address(0), "ERC7540Vault/invalid-manager");
        require(_loanManager != address(0), "ERC7540Vault/invalid-loan-manager");
        _asset = _assetAddress;
        share = _share; 
        dToken = _dToken;
        poolManager = _poolManager;
        poolId = IPoolManager(_poolManager).getPoolCount();
        loanManager = _loanManager;
        assetDecimals = IERC20Metadata(_assetAddress).decimals();
    }

    function asset() public view override(ERC4626Upgradeable, IERC4626) returns (address) {
        return _asset;
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
        userVaultData[owner].pendingDepositRequest += assets.toUint128();
        IERC20(asset()).transferFrom(owner, address(this), assets);
        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    function fulfillDepositRequest(uint256 assets, address receiver) external onlyPoolManager returns (uint256 requestId) {
        uint256 shares = assets;
        userVaultData[receiver].maxMint += shares.toUint128();
        uint128 newPendingDepositRequest = userVaultData[receiver].pendingDepositRequest - assets.toUint128();
        userVaultData[receiver].pendingDepositRequest = newPendingDepositRequest;
        IERC20(asset()).approve(share, assets);
        IERC20(asset()).transfer(share, assets);
        ISToken sToken = ISToken(share); 
        sToken.mint(msg.sender, address(this), assets);

        emit DepositClaimable(receiver, REQUEST_ID, assets, shares);
        return REQUEST_ID;
    }
    
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        Validation.validateController(controller, receiver, isOperator);
        IERC20(share).transferFrom(address(this), receiver, shares);
        return shares;
    }

    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares) {
        Validation.validateController(controller, receiver, isOperator);
        shares = assets;
        userVaultData[receiver].maxMint = userVaultData[receiver].maxMint - shares.toUint128();
        ISToken(share).transfer(receiver, shares);
        emit Deposit(controller, receiver, shares, shares);
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
        userVaultData[owner].pendingRedeemRequest += shares.toUint128();
        ISToken sToken = ISToken(share);
        sToken.transferFrom(owner, address(this), shares);
        
        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function fulfillRedeemRequest(
        uint256 shares,
        address receiver
    ) external onlyPoolManager returns (uint256 requestId) {
        Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
        uint256 assets = shares;
        uint256 cumulativeDistributionsPerShare = pool.cumulativeDistributionsPerShare;
        uint256 userBaseline = ISToken(share).getUserBaseline(receiver);
        uint256 userClaimableAssets = shares.rayDiv(cumulativeDistributionsPerShare - userBaseline);
        
        userVaultData[receiver].maxWithdraw = userVaultData[receiver].maxWithdraw + userClaimableAssets.toUint128();
        userVaultData[receiver].pendingRedeemRequest = 
            userVaultData[receiver].pendingRedeemRequest > shares ? userVaultData[receiver].pendingRedeemRequest - shares.toUint128() : 0;
        
        if (userVaultData[receiver].pendingRedeemRequest == 0) delete userVaultData[receiver].pendingRedeemRequest;

        emit RedeemClaimable(receiver, REQUEST_ID, assets, shares);
        return REQUEST_ID;
    }

    function redeem(uint256 assets, address controller, address owner) 
        public 
        override(ERC4626Upgradeable, IERC7540Vault) 
        returns (uint256 shares)
    {
        Validation.validateController(controller, owner, isOperator);
        Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
        shares = assets;
        userVaultData[owner].maxWithdraw = 
            userVaultData[owner].maxWithdraw > assets ? userVaultData[owner].maxWithdraw - assets.toUint128() : 0;

        ISToken(share).burn(address(this), owner, shares);
        
        emit Withdraw(address(this), controller, owner, assets, shares);
        return shares;
    }

    function initLoan(
        address borrower, 
        address originator,
        uint256 retentionRate,
        uint256 principal, 
        uint16 termMonths,
        uint256 interestRate
    ) external onlyPoolManager {
        Types.Loan memory loan = ILoanManager(loanManager).createLoan(
            nextLoanId++, 
            originator, 
            retentionRate, 
            principal, 
            termMonths, 
            interestRate
        );

        loans[borrower].push(loan);
        
        // Mint debt tokens to the originator
        IDToken(dToken).mint(originator, principal);
        
        emit LoanInitialized(loan.id, borrower, principal, termMonths, interestRate);
    }

    function batchInitLoan(
        Types.BatchLoanData[] calldata loanData,
        address originator
    ) external onlyPoolManager {
        uint256[] memory loanIds = new uint256[](loanData.length);
        address[] memory borrowers = new address[](loanData.length);
        uint256[] memory principals = new uint256[](loanData.length);
        
        uint256 totalPrincipal = 0;
        
        for (uint256 i = 0; i < loanData.length; i++) {
            Types.BatchLoanData calldata data = loanData[i];
            Types.Loan memory loan = ILoanManager(loanManager).createLoan(
                nextLoanId, 
                originator, 
                data.retentionRate, 
                data.principal, 
                data.termMonths, 
                data.interestRate
            );

            loans[data.borrower].push(loan);
            
            // Accumulate principal
            totalPrincipal += data.principal;
            
            // Store data for event
            loanIds[i] = nextLoanId;
            borrowers[i] = data.borrower;
            principals[i] = data.principal;
            
            nextLoanId++;
        }
        
        // Mint all debt tokens at once
        if (totalPrincipal > 0) {
            IDToken(dToken).mint(originator, totalPrincipal);
        }
        
        emit BatchLoanInitialized(originator, loanIds, borrowers, principals);
    }

    function repay(
        uint256 assets,
        address caller,
        address onBehalfOf,
        uint256 loanId
    ) external onlyPoolManager returns (uint256 interestPaid, uint256 interestRate) {
        Types.Loan storage loan = loans[onBehalfOf][loanId];
        require(loan.status == Types.Status.Active, "ERC7540Vault/loan-not-active");

        (
            Types.Loan memory updatedLoan, 
            uint256 principalPortion, 
            uint256 interestPortion,
        ) = ILoanManager(loanManager).processRepayment(
                loan,
                assets,
                assetDecimals
        );

        loans[onBehalfOf][loanId] = updatedLoan;

        uint256 totalPayment = principalPortion + interestPortion;
        IERC20(asset()).transferFrom(caller, address(this), totalPayment);
        // Transfer the entire payment to sToken instead of Aave operations
        IERC20(asset()).transfer(share, totalPayment);
        IDToken(dToken).burn(onBehalfOf, principalPortion);

        emit LoanRepaid(loanId, onBehalfOf, principalPortion, interestPortion);
        return (interestPortion, loan.interestRate);
    }

    function batchRepayLoans(
        Types.BatchRepaymentData[] calldata repayments,
        address originator
    ) external onlyPoolManager returns (uint256 totalInterestPaid) {
        uint256 totalRepayment = 0;
        uint256 totalInterestPortion = 0;
        uint256 totalPrincipalPortion = 0;
        
        for (uint256 i = 0; i < repayments.length; i++) {
            Types.BatchRepaymentData calldata data = repayments[i];
            
            (uint256 principalPortion, uint256 interestPortion) = _processBatchRepayment(
                data.borrower,
                data.loanId,
                data.paymentAmount
            );

            totalRepayment += data.paymentAmount;
            totalInterestPortion += interestPortion;
            totalPrincipalPortion += principalPortion;
        }

        uint256 totalAssets = totalInterestPortion + totalPrincipalPortion;
        IERC20(asset()).transferFrom(originator, address(this), totalAssets);
        IERC20(asset()).transfer(share, totalAssets);
        IDToken(dToken).burn(originator, totalPrincipalPortion);

        emit BatchRepaymentProcessed(originator, new uint256[](0), new address[](0), new uint256[](0), new uint256[](0));
        
        return totalInterestPortion;
    }

    function _processBatchRepayment(
        address borrower,
        uint256 loanId,
        uint256 paymentAmount
    ) internal returns (uint256 principalPortion, uint256 interestPortion) {
        Types.Loan storage loan = loans[borrower][loanId];
        require(loan.status == Types.Status.Active, "ERC7540Vault/loan-not-active");

        (
            Types.Loan memory updatedLoan, 
            uint256 principal, 
            uint256 interest,
            uint256 remainingInterest
        ) = ILoanManager(loanManager).processRepayment(
                loan,
                paymentAmount,
                assetDecimals
            );

        loans[borrower][loanId] = updatedLoan;
        
        return (principal, interest);
    }

    function transferSaleProceeds(uint256 amount, address originator) external onlyPoolManager {
        ISToken(share).transferUnderlyingToOriginator(amount, originator);
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256) {
        return userVaultData[controller].pendingRedeemRequest;
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256) {
        uint256 currentSTokenBalance = ISToken(share).balanceOf(controller);
        return currentSTokenBalance;
    }

    function getShare() external view returns (address) {
        return share;
    }

    function getUserVaultData(address user) external view returns (Types.UserVaultData memory) {
        return userVaultData[user];
    }

    function getDToken() external view returns (address) {
        return dToken;
    }

    function getLoan(address borrower, uint256 loanId) external view returns (Types.Loan memory loan) {
        return loans[borrower][loanId];
    }

    function convertToShares(uint256 assets) 
        public 
        pure 
        override(ERC4626Upgradeable, IERC7540Vault) 
        returns (uint256) 
    {
        return assets;
    }

    function convertToAssets(uint256 shares) 
        public 
        pure 
        override(ERC4626Upgradeable, IERC7540Vault) 
        returns (uint256) 
    {
        return shares;
    }
}
