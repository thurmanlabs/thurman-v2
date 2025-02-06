// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "../math/WadRayMath.sol";
import {Types} from "../types/Types.sol";
import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";

library Loan {
    using WadRayMath for uint256;

    function calculateMonthlyPayment(
        uint256 principal,
        uint256 interestRate,  // Annual interest rate in basis points (e.g., 600 = 6%)
        uint256 totalPayments
    ) public pure returns (uint256) {
        // Convert annual rate to monthly (divide by 12 and 10000 for basis points)
        uint256 monthlyRate = interestRate.rayDiv(12).rayMul(WadRayMath.RAY).rayDiv(10000);
        
        // Calculate (1 + r)^n
        uint256 rateFactorRay = WadRayMath.RAY + monthlyRate;
        uint256 rateFactorPower = rateFactorRay.rayPow(totalPayments);
        
        // Calculate P * r * (1 + r)^n
        uint256 numerator = principal.rayMul(monthlyRate.rayMul(rateFactorPower));
        
        // Calculate (1 + r)^n - 1
        uint256 denominator = rateFactorPower - WadRayMath.RAY;
        
        // Return P * r * (1 + r)^n / ((1 + r)^n - 1)
        return numerator.rayDiv(denominator);
    }

    function getMonthlyInterest(Types.Loan storage loan) public view returns (uint256) {
        uint256 remainingBalance = loan.remainingBalance;
        return remainingBalance.rayMul(loan.interestRate).rayDiv(12).rayDiv(10000);
    }

    function initLoan(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        address borrower,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) public {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.initLoan(borrower, principal, termMonths, interestRate);
    }

    function repayLoan(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address onBehalfOf,
        uint256 loanId
    ) public {  
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.repay(assets, onBehalfOf, loanId);
    }
}