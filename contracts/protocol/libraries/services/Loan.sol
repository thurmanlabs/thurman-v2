// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {Types} from "../types/Types.sol";
import {Validation} from "./Validation.sol";


library Loan {
    using WadRayMath for uint256;

    function initLoan(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        address borrower,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        Validation.validateInitLoan(pool, principal, termMonths, interestRate);
        uint256 collateralAllocated = principal.rayMul(pool.collateralCushion);
        vault.initLoan(borrower, collateralAllocated, principal, termMonths, interestRate);
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
        vault.repay(assets, msg.sender, onBehalfOf, loanId);
        pool.aaveBorrowBalance = IVariableDebtToken(pool.variableDebtToken).balanceOf(pool.vault);
        pool.ltvRatio = pool.aaveBorrowBalance.rayDiv(pool.aaveCollateralBalance);
    }
}