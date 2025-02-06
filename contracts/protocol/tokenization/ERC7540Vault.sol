// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {ISToken} from "../../interfaces/ISToken.sol";
import {IDToken} from "../../interfaces/IDToken.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Types} from "../libraries/types/Types.sol";
import {Validation} from "../libraries/services/Validation.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {Loan} from "../libraries/services/Loan.sol";

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
    address public aavePool;
    address public share;
    address public dToken;
    mapping(address => Types.UserVaultData) public userVaultData;
    mapping(address => Types.Loan[]) public loans;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _asset,
        address _share,
        address _dToken,
        address _aavePool,
        address _poolManager
    ) external initializer {
        __ERC4626_init(IERC20(_asset));
        require(_asset != address(0), "ERC7540Vault/invalid-asset");
        require(_share != address(0), "ERC7540Vault/invalid-share");
        require(_dToken != address(0), "ERC7540Vault/invalid-dToken");
        require(_aavePool != address(0), "ERC7540Vault/invalid-pool");
        require(_poolManager != address(0), "ERC7540Vault/invalid-manager");
        
        share = _share;
        aavePool = _aavePool;
        poolManager = _poolManager;
        dToken = _dToken;
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

    function initLoan(
        address borrower, 
        uint256 principal, 
        uint16 termMonths,
        uint256 interestRate
    ) external onlyPoolManager {
        Validation.validateInitLoan(principal, termMonths, interestRate);
        uint256 monthlyPayment = Loan.calculateMonthlyPayment(principal, interestRate, termMonths);
        uint256 currentBorrowerRate = IPool(aavePool).getReserveData(asset()).currentStableBorrowRate;
        uint256 loanId = nextLoanId++;
        loans[borrower].push(Types.Loan({
            id: loanId,
            principal: principal,
            interestRate: interestRate,
            termMonths: termMonths,
            nextPaymentDate: uint40(block.timestamp + 30 days),
            remainingBalance: principal,
            remainingMonthlyPayment: monthlyPayment,
            currentPaymentIndex: 0,
            monthlyPayment: monthlyPayment,
            status: Types.Status.Active,
            currentBorrowerRate: currentBorrowerRate
        }));
        IDToken(dToken).mint(borrower, principal);
        IPool(aavePool).borrow(asset(), principal, 1, 0, address(this));
        IERC20(asset()).transfer(borrower, principal);
        
        emit LoanInitialized(loanId, borrower, principal, termMonths, interestRate);
    }

    function repay(
        uint256 assets, 
        address onBehalfOf,
        uint256 loanId
    ) external onlyPoolManager {
        Types.Loan storage loan = loans[onBehalfOf][loanId];
        require(loan.status == Types.Status.Active, "ERC7540Vault/loan-not-active");
        require(loan.remainingBalance >= assets, "ERC7540Vault/insufficient-loan-balance");
        loan.currentPaymentIndex++;
        uint256 interest = Loan.getMonthlyInterest(loan);
        uint256 principal = assets - interest;
        // TODO: Make sure that partial payments are allowed and calculated correctly
        // TODO: Make sure that additional payments above the monthly payment are applied to the remaining balance
        if (principal > 0) {
            loan.remainingBalance -= principal;
        }
        loan.remainingMonthlyPayment -= assets;
        if (loan.remainingMonthlyPayment == 0) {
            loan.nextPaymentDate += 30 days;
        }
        if (loan.remainingBalance == 0) {
            loan.status = Types.Status.Closed;
        }

        // Calculate the amount to repay to Aave
        // TODO: Make sure that the amount is calculated correctly
        uint256 aaveRepaymentAmount = assets
            .rayMul(loan.currentBorrowerRate)
            .rayMul(
                WadRayMath.RAY.rayDiv(loan.termMonths)
        );

        uint256 margin = assets - aaveRepaymentAmount;

        // Update the borrower rate
        uint256 currentBorrowerRate = IPool(aavePool).getReserveData(asset()).currentStableBorrowRate;
        loan.currentBorrowerRate = currentBorrowerRate;

        IPool(aavePool).repay(asset(), aaveRepaymentAmount, 1, address(this)); 
        IPool(aavePool).supply(asset(), margin, address(this), 0);
        IERC20(asset()).transfer(onBehalfOf, principal);
        IDToken(dToken).burn(onBehalfOf, principal);
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
