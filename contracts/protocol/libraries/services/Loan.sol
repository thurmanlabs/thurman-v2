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
        vault.initLoan(borrower, originator, retentionRate, principal, termMonths, interestRate);
        pool.totalPrincipal += principal;
        IOriginatorRegistry(pool.originatorRegistry).recordOriginatedPrincipal(originator, principal, poolId);
    }

    function batchInitLoan(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        Types.BatchLoanData[] calldata loanData,
        address originator
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        Validation.validateBatchInitLoan(pool, originator, loanData);
        vault.batchInitLoan(loanData, originator);


        for (uint256 i = 0; i < loanData.length; i++) {
            Types.BatchLoanData calldata data = loanData[i];
            pool.totalPrincipal += data.principal;
            IOriginatorRegistry(pool.originatorRegistry).recordOriginatedPrincipal(originator, data.principal, poolId);
        }
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
        Types.Loan memory loan = vault.getLoan(onBehalfOf, loanId);
        Validation.validateRepayLoan(pool, onBehalfOf, msg.sender, assets);

        (uint256 interestPaid,) = vault.repay(assets, msg.sender, onBehalfOf, loanId);
        uint256 accruedToTreasury = interestPaid.rayMul(pool.marginFee);
        pool.accruedToTreasury += accruedToTreasury;

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
        
    }

    function batchRepayLoan(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        Types.BatchRepaymentData[] calldata repayments,
        address originator
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        Validation.validateBatchRepayLoan(pool, originator, msg.sender, repayments);
        vault.batchRepayLoans(repayments, originator);
    }
}