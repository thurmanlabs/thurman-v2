// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IOriginatorRegistry} from "../../../interfaces/IOriginatorRegistry.sol";
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
        address originator,
        uint256 retentionRate,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        Validation.validateInitLoan(pool, borrower, principal, termMonths, interestRate);
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(vault.asset());
        uint256 aaveBorrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
        uint256 aaveCollateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
        vault.initLoan(borrower, originator, retentionRate, principal, termMonths, interestRate);
        pool.ltvRatio = aaveCollateralBalance == 0 ? 0 : aaveBorrowBalance.rayDiv(aaveCollateralBalance);
        pool.ltvRatio = aaveCollateralBalance == 0 ? 0 : aaveBorrowBalance.rayDiv(aaveCollateralBalance);
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

        Types.Loan memory loan = vault.getLoan(onBehalfOf, loanId);

        (uint256 interestPaid,) = vault.repay(assets, msg.sender, onBehalfOf, loanId);

        uint256 aaveCollateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
        pool.ltvRatio = aaveCollateralBalance == 0 ? 0 : aaveBorrowBalance.rayDiv(aaveCollateralBalance);
        uint256 accruedToTreasury = interestPaid.rayMul(pool.marginFee);
        pool.accruedToTreasury += accruedToTreasury;
        if (accruedToTreasury > 0) {
            IPool(pool.aavePool).supply(vault.asset(), accruedToTreasury, pool.vault, 0);
        }

        if (pool.originatorRegistry != address(0) && loan.originator != address(0) && loan.retentionRate > 0) {
            uint256 originatorPortion = interestPaid.rayMul(loan.retentionRate);
            IOriginatorRegistry(pool.originatorRegistry).accrueInterest(
                loan.originator, 
                originatorPortion, 
                poolId,
                loanId
            );
            
            // Reduce treasury accrual by originator portion to avoid double-counting
            if (originatorPortion < accruedToTreasury) {
                accruedToTreasury -= originatorPortion;
                pool.accruedToTreasury -= originatorPortion;
            }
        }
        
        if (accruedToTreasury > 0) {
            IPool(pool.aavePool).supply(vault.asset(), accruedToTreasury, pool.vault, 0);
        }
    }
}