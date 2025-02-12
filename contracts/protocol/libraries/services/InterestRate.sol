// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "../math/WadRayMath.sol";
import {Types} from "../types/Types.sol";
library InterestRate {
    using WadRayMath for uint256;

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
        Types.Pool memory pool
    ) internal returns (uint256, uint256) {
        if (loan.status != Types.Status.Active || 
            loan.currentPaymentIndex >= loan.termMonths) {
            return (loan.monthlyPayment, loan.projectedLossRate);
            }

        uint256 newRate = calculateAdjustedLossRate(
            loan.projectedLossRate,
            pool.amountGuaranteed,
            pool.aaveBorrowBalance
        );

        if (newRate == loan.projectedLossRate) {
            return (loan.monthlyPayment, loan.projectedLossRate);
        }

        uint256 newMonthlyPayment = calculateMonthlyPayment(
            loan.principal,
            newRate,
            loan.termMonths
        );

        loan.monthlyPayment = newMonthlyPayment;
        loan.projectedLossRate = newRate;
        loan.interestRate = pool.baseRate + newRate;

        return (newMonthlyPayment, newRate);
    }

    function calculateMonthlyPayment(
        uint256 principal,
        uint256 interestRate,  // Annual interest rate in basis points (e.g., 600 = 6%)
        uint256 totalPayments
    ) internal pure returns (uint256) {
        // Convert principal to RAY
        uint256 principalRay = WadRayMath.wadToRay(principal);
        
        uint256 monthlyRate = interestRate.rayDiv(12);  // Convert to monthly rate
        
        // Debug requires
        require(monthlyRate > 0, "Monthly rate is 0");
        require(monthlyRate <= WadRayMath.RAY, "Monthly rate too high");
        
        // Calculate (1 + r)
        uint256 rateFactorRay = WadRayMath.RAY + monthlyRate;
        require(rateFactorRay >= WadRayMath.RAY, "Rate factor < RAY");
        
        // Calculate (1 + r)^n
        uint256 rateFactorPower = rateFactorRay.rayPow(totalPayments);
        
        // Calculate P * r * (1 + r)^n
        uint256 numerator = principalRay.rayMul(monthlyRate.rayMul(rateFactorPower));
        
        // Calculate (1 + r)^n - 1
        uint256 denominator = rateFactorPower - WadRayMath.RAY;
        
        // Return result converted back from RAY
        return WadRayMath.rayToWad(numerator.rayDiv(denominator));
    }
}