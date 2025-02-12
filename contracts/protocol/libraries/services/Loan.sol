// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {Types} from "../types/Types.sol";
import {InterestRate} from "./InterestRate.sol";
import {Validation} from "./Validation.sol";

library Loan {
    using WadRayMath for uint256;
    using InterestRate for uint256;

    function initLoan(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        address borrower,
        uint256 principal,
        uint16 termMonths,
        uint256 projectedLossRate
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        Validation.validateInitLoan(pool, principal, termMonths, pool.baseRate + projectedLossRate);
        uint256 adjustedLossRate = projectedLossRate.calculateAdjustedLossRate(principal, pool.aaveBorrowBalance);
        uint256 collateralAllocated = principal.rayMul(pool.collateralCushion);
        vault.initLoan(borrower, collateralAllocated, principal, termMonths, adjustedLossRate, pool.baseRate);
        pool.aaveBorrowBalance = IVariableDebtToken(pool.variableDebtToken).balanceOf(pool.vault);
        pool.ltvRatio = pool.aaveBorrowBalance.rayDiv(pool.aaveCollateralBalance);
    }

    function repayLoan(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address onBehalfOf,
        uint256 loanId
    ) internal {  
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        // TODO: Get loan from vault storage for recalculating monthly payments and interest rate
        Types.Loan storage loan = vault.getLoan(onBehalfOf, loanId);
        (uint256 remainingInterest, uint256 interestRate) = vault.repay(pool, assets, msg.sender, onBehalfOf, loanId);
        pool.aaveBorrowBalance = IVariableDebtToken(pool.variableDebtToken).balanceOf(pool.vault);
        pool.ltvRatio = pool.aaveBorrowBalance.rayDiv(pool.aaveCollateralBalance);
        uint256 accruedToTreasury = remainingInterest.rayMul(pool.marginFee.rayDiv(interestRate));
        pool.accruedToTreasury += accruedToTreasury;
        IPool(pool.aavePool).supply(pool.underlyingAsset, accruedToTreasury, pool.vault, 0);
    }
}