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
        uint256 coverageRatio = guaranteedAmount.wadToRay().rayDiv(totalBorrowed.wadToRay());
        uint256 adjustedCoverageRatio = coverageRatio > WadRayMath.RAY ? WadRayMath.RAY : coverageRatio;
        return projectedLossRate.wadToRay().rayMul(WadRayMath.RAY - adjustedCoverageRatio);
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

        // Calculate new rate (slot 3)
        uint256 newRate = calculateAdjustedLossRate(
            uint256(loan.projectedLossRate),
            amountGuaranteed,
            aaveBorrowBalance
        );

        if (newRate == loan.projectedLossRate) {
            return (loan.monthlyPayment, loan.projectedLossRate);
        }

        // Calculate new payment (slots 1, 2)
        uint256 newPayment = LoanMath.calculateMonthlyPayment(
            uint256(loan.principal),
            newRate,
            loan.termMonths
        );

        // Update loan state (slots 3, 4)
        loan.monthlyPayment = uint128(newPayment);
        loan.projectedLossRate = uint128(newRate);
        loan.interestRate = uint128(baseRate + newRate);

        return (newPayment, newRate);
    }
}