// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
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
        Validation.validateInitLoan(pool, principal, termMonths, pool.config.baseRate + projectedLossRate);
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(vault.asset());
        uint256 aaveBorrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
        uint256 aaveCollateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
        uint256 adjustedLossRate = projectedLossRate.calculateAdjustedLossRate(principal, aaveBorrowBalance);
        vault.initLoan(borrower, principal, termMonths, adjustedLossRate, pool.config.baseRate); 
        pool.ltvRatio = aaveBorrowBalance.rayDiv(aaveCollateralBalance);
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
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(vault.asset());
        uint256 aaveBorrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
        (uint256 remainingInterest, uint256 interestRate) = vault.repay(pool.amountGuaranteed, aaveBorrowBalance, pool.config.baseRate, assets, msg.sender, onBehalfOf, loanId);
        uint256 aaveCollateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
        pool.ltvRatio = aaveBorrowBalance.rayDiv(aaveCollateralBalance);
        uint256 accruedToTreasury = remainingInterest.rayMul(pool.marginFee.rayDiv(interestRate));
        pool.accruedToTreasury += accruedToTreasury;
        IPool(pool.aavePool).supply(vault.asset(), accruedToTreasury, pool.vault, 0);
    }
}