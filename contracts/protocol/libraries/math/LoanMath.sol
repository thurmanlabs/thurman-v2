// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "./WadRayMath.sol";
import {Types} from "../types/Types.sol";

library LoanMath {
    using WadRayMath for uint256;

    // Step 1: Calculate monthly rate
    function getMonthlyRate(uint256 annualRate) internal pure returns (uint256) {
        return annualRate.rayDiv(12);
    }

    // Step 2: Calculate rate factor
    function getRateFactor(uint256 monthlyRate) internal pure returns (uint256) {
        return WadRayMath.RAY + monthlyRate;
    }

    // Step 3: Calculate power
    function getRateFactorPower(uint256 rateFactor, uint256 terms) internal pure returns (uint256) {
        return rateFactor.rayPow(terms);
    }

    // Step 4: Calculate final payment
    function calculatePayment(
        uint256 principal,
        uint256 monthlyRate,
        uint256 rateFactorPower
    ) internal pure returns (uint256) {
        uint256 principalRay = WadRayMath.wadToRay(principal);
        return WadRayMath.rayToWad(
            principalRay.rayMul(monthlyRate.rayMul(rateFactorPower))
            .rayDiv(rateFactorPower - WadRayMath.RAY)
        );
    }

    // Main function that uses the above steps
    function calculateMonthlyPayment(
        uint256 principal,
        uint256 interestRate,
        uint256 totalPayments
    ) internal pure returns (uint256) {
        Types.MonthlyPaymentVars memory vars;
        
        // Pack calculations into struct to avoid stack depth
        vars.monthlyRate = interestRate.rayDiv(12);
        vars.rateFactor = WadRayMath.RAY + vars.monthlyRate;
        vars.rateFactorPower = vars.rateFactor.rayPow(totalPayments);
        vars.principalRay = WadRayMath.wadToRay(principal);

        // Single calculation using struct variables
        return WadRayMath.rayToWad(
            vars.principalRay
                .rayMul(vars.monthlyRate.rayMul(vars.rateFactorPower))
                .rayDiv(vars.rateFactorPower - WadRayMath.RAY)
        );
    }
} 