// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "./WadRayMath.sol";
import {MathUtils} from "./MathUtils.sol";
import {Types} from "../types/Types.sol";
import "hardhat/console.sol";

library LoanMath {
    using WadRayMath for uint256;

    function calculateMonthlyPayment(
        uint256 principal,
        uint256 interestRate,
        uint16 termMonths
    ) internal pure returns (uint256) {
        uint256 rateFactorPower = WadRayMath.wadToRay(WadRayMath.WAD + interestRate / 12).rayPow(termMonths);
        uint256 rateFactorWad = WadRayMath.rayToWad(rateFactorPower);
        return principal * (interestRate / 12) * rateFactorWad / 
               (WadRayMath.WAD * (rateFactorWad - WadRayMath.WAD));
    }

    function calculateMonthlyInterest(
        Types.Loan memory loan,
        uint256 remainingBalance,
        uint8 assetDecimals
    ) internal pure returns (uint256) {
        // Convert remainingBalance to WAD (18 decimals) for calculation
        uint256 balanceWad = WadRayMath.toWad(remainingBalance, assetDecimals);
        
        // Calculate monthly rate in WAD format
        uint256 monthlyRate = loan.interestRate / MathUtils.MONTHS_PER_YEAR;
        
        // Calculate interest in WAD using wadMul
        uint256 interestWad = WadRayMath.wadMul(balanceWad, monthlyRate);
        
        // Convert interest from WAD to token decimals
        uint256 interest = WadRayMath.fromWad(interestWad, assetDecimals);
        
        return interest;
    }
} 