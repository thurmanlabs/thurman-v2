// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "./WadRayMath.sol";
import {Types} from "../types/Types.sol";
import "hardhat/console.sol";

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
        uint16 termMonths
    ) internal pure returns (uint256) {
        require(termMonths > 0, "LoanMath/invalid-term");
        require(interestRate > 0, "LoanMath/invalid-rate");
        require(principal > 0, "LoanMath/invalid-principal");

        console.log("LoanMath inputs:");
        console.log("- Principal:", principal);
        console.log("- Interest Rate:", interestRate);
        console.log("- Term Months:", termMonths);

        // Convert interest rate to monthly (keeping in WAD)
        uint256 monthlyRate = interestRate / 12;
        
        // Convert to RAY only for the power calculation
        uint256 baseWad = WadRayMath.WAD + monthlyRate;  // (1 + r) in WAD
        uint256 baseRay = WadRayMath.wadToRay(baseWad);  // Convert to RAY for power
        
        // Calculate (1 + r)^n in RAY
        uint256 rateFactorPower = baseRay.rayPow(termMonths);
        
        // Convert back to WAD for remaining calculations
        uint256 rateFactorPowerWad = WadRayMath.rayToWad(rateFactorPower);
        
        // Calculate in WAD: P * r * (1 + r)^n / ((1 + r)^n - 1)
        uint256 numerator = principal * monthlyRate * rateFactorPowerWad / WadRayMath.WAD;
        uint256 denominator = rateFactorPowerWad - WadRayMath.WAD;
        
        require(denominator > 0, "LoanMath/zero-denominator");
        return numerator / denominator;
    }
} 