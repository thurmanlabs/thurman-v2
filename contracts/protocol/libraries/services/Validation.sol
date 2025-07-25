// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {ISToken} from "../../../interfaces/ISToken.sol";
import {Types} from "../types/Types.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IPool} from "../../../interfaces/IPool.sol";

library Validation {
    using WadRayMath for uint256;

    function validateSetOperator(address operator) internal view {
        require(operator != msg.sender, "ERC7540Vault/cannot-set-self-as-operator");
    }

    function validateController(
        address controller, 
        address owner,
        mapping(address => mapping(address => bool)) storage isOperator
    ) internal view {
        require(controller == owner || isOperator[owner][controller], "ERC7540Vault/invalid-controller");
    }

    function validateRequestDeposit(
        Types.Pool memory pool,
        address owner,
        uint256 assets,
        uint256 currentAssets
    ) internal view {
        Types.PoolConfig memory config = pool.config;

        require(owner != address(0), "Deposit/invalid-owner");
        require(!config.isPaused, "Deposit/pool-paused");
        require(config.depositsEnabled, "Deposit/deposits-disabled");
        require(assets >= config.minDepositAmount, "Deposit/amount-too-small");
        require(assets <= config.maxDepositAmount, "Deposit/amount-too-large");
        require(assets > 0, "Deposit/invalid-assets");
        require(assets <= IERC20(vault.asset()).balanceOf(owner), "Deposit/insufficient-assets");
        require(currentAssets + assets <= config.depositCap, "Deposit/cap-exceeded");
    }

    function validateFulfillDepositRequest(
        Types.Pool memory pool,
        uint256 assets,
        uint256 pendingDepositRequest
    ) internal pure {
        Types.PoolConfig memory config = pool.config;
        require(!config.isPaused, "Deposit/pool-paused");
        require(config.depositsEnabled, "Deposit/deposits-disabled");
        require(pendingDepositRequest != 0, "Deposit/no-pending-deposit-request");
        require(assets > 0, "Deposit/invalid-assets");
        require(pendingDepositRequest >= assets.toUint128(), "Deposit/insufficient-pending-request");
    }

    function validateDeposit(
        Types.Pool memory pool,
        uint256 assets,
        uint256 currentAssets,
        uint256 maxMint
    ) internal view {
        Types.PoolConfig memory config = pool.config;
        require(!config.isPaused, "Deposit/pool-paused");
        require(config.depositsEnabled, "Deposit/deposits-disabled");
        require(assets > 0, "Deposit/invalid-assets");
        require(currentAssets + assets <= config.depositCap, "Deposit/cap-exceeded");
        require(maxMint >= assets, "Deposit/insufficient-mint-allowance");
    }

    function validateRequestRedeem(
        Types.Pool memory pool,
        address sToken,
        uint256 assets,
        uint256 shares,
        address owner
    ) internal view {
        Types.PoolConfig memory config = pool.config;
        uint256 userBaseline = ISToken(sToken).getUserBaseline(owner);
        uint256 cumulativeDistributionsPerShare = pool.cumulativeDistributionsPerShare;
        uint256 userClaimableAssets = shares.rayDiv(cumulativeDistributionsPerShare - userBaseline);
        require(!config.isPaused, "Redeem/pool-paused");
        require(config.withdrawalsEnabled, "Redeem/withdrawals-disabled");
        require(shares > 0, "Redeem/invalid-shares");
        require(shares <= ISToken(sToken).balanceOf(owner), "ERC7540Vault/insufficient-shares");
        require(userClaimableAssets >= assets, "Redeem/insufficient-claimable-assets");
    }

    function validateFulfillRedeemRequest(
        Types.Pool memory pool,
        uint256 shares,
        uint256 pendingRedeemRequest
    ) internal pure {
        Types.PoolConfig memory config = pool.config;
        require(!config.isPaused, "Redeem/pool-paused");
        require(config.withdrawalsEnabled, "Redeem/withdrawals-disabled");
        require(shares > 0, "Redeem/invalid-shares");
        require(pendingRedeemRequest != 0, "Redeem/no-pending-redeem-request");
    }

    function validateRedeem(
        Types.Pool memory pool,
        uint256 claimableAmount,
        uint256 pendingRedeemRequest,
        uint256 maxWithdraw,
        uint256 assets
    ) internal pure {
        Types.PoolConfig memory config = pool.config;
        require(!config.isPaused, "Redeem/pool-paused");
        require(config.withdrawalsEnabled, "Redeem/withdrawals-disabled");
        require(pendingRedeemRequest != 0, "Redeem/no-pending-redeem-request");
        require(claimableAmount >= assets, "Redeem/insufficient-claimable-amount");
        require(assets <= claimableAmount, "ERC7540Vault/insufficient-claimable-amount");
        require(userVaultData.maxWithdraw >= shares, "ERC7540Vault/insufficient-max-withdraw");
    }

    function validateInitLoan(
        Types.Pool memory pool,
        address borrower,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) internal pure {
        Types.PoolConfig memory config = pool.config;
        require(!config.isPaused, "Loan/pool-paused");
        require(config.borrowingEnabled, "Loan/borrowing-disabled");
        require(borrower != address(0), "Loan/invalid-borrower");
        require(principal > 0, "Loan/invalid-principal");
        require(termMonths > 0, "Loan/invalid-term");
        require(interestRate > 0, "Loan/invalid-interest-rate");
    }

    function validateBatchInitLoan(
        address originator,
        Types.BatchLoanData[] calldata loanData
    ) internal pure {
        require(originator != address(0), "Loan/invalid-originator");
        require(loanData.length > 0, "Loan/empty-batch");
        require(loanData.length <= 100, "Loan/batch-too-large");

        for (uint256 i = 0; i < loanData.length; i++) {
            Types.BatchLoanData calldata data = loanData[i];
            validateInitLoan(pool, data.borrower, data.principal, data.termMonths, data.interestRate);
        }
    }

    function validateTransferSaleProceeds(
        Types.Pool memory pool,
        address originator,
        uint256 amount
    ) internal view {
        IOriginatorRegistry originatorRegistry = IOriginatorRegistry(pool.originatorRegistry);
        require(originator != address(0), "Pool/invalid-originator");
        require(amount > 0, "Pool/invalid-amount");
        require(originatorRegistry.isRegisteredOriginator(originator), "Pool/originator-not-registered");
        require(pool.totalPrincipal > 0, "Pool/no-principal");
        require(pool.totalDeposits > 0, "Pool/no-deposits");
        require(pool.totalPrincipal <= pool.totalDeposits, "Pool/principal-exceeds-deposits");
    }
        
}
