// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "../math/WadRayMath.sol";
import {Types} from "../types/Types.sol";
import {LoanMath} from "../math/LoanMath.sol";

library InterestRate {
    using WadRayMath for uint256;
    using LoanMath for uint256;

    function calculateAdjustedLossRate(
        uint256 projectedLossRate,
        uint256 guaranteedAmount,
        uint256 totalBorrowed  
    ) internal pure returns (uint256) {
        // If no borrows, return full projected loss rate
        if (totalBorrowed == 0) {
            return projectedLossRate;
        }
        
        // Calculate coverage ratio in WAD
        uint256 coverageRatio = (guaranteedAmount * WadRayMath.WAD) / totalBorrowed;
        uint256 adjustedCoverageRatio = coverageRatio > WadRayMath.WAD ? WadRayMath.WAD : coverageRatio;
        
        // Adjust loss rate based on coverage - all in WAD
        return (projectedLossRate * (WadRayMath.WAD - adjustedCoverageRatio)) / WadRayMath.WAD;
    }

    function getCurrentMonthlyPayment(
        Types.Loan storage loan,
        uint256 amountGuaranteed,
        uint256 aaveBorrowBalance,
        uint256 baseRate
    ) internal returns (uint256, uint256) {
        // Check loan status (slot 1)
        if (loan.status != Types.Status.Active || 
            loan.currentPaymentIndex >= loan.termMonths) {
            return (loan.monthlyPayment, loan.projectedLossRate);
        }

        // Calculate new rate (slot 3) - keeping in WAD precision
        uint256 newRate = calculateAdjustedLossRate(
            uint256(loan.projectedLossRate),
            amountGuaranteed,
            aaveBorrowBalance
        );

        if (newRate == loan.projectedLossRate) {
            return (loan.monthlyPayment, loan.projectedLossRate);
        }

        // Calculate new payment (slots 1, 2) - all rates in WAD
        uint256 newPayment = LoanMath.calculateMonthlyPayment(
            uint256(loan.principal),
            newRate,  // Already in WAD from calculateAdjustedLossRate
            loan.termMonths
        );

        // Update loan state (slots 3, 4) - store everything in WAD
        loan.monthlyPayment = uint128(newPayment);
        loan.projectedLossRate = uint128(newRate);
        loan.interestRate = uint128(baseRate + newRate);  // Both in WAD

        return (newPayment, newRate);
    }
}