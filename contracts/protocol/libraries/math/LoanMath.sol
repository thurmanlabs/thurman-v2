// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "./WadRayMath.sol";
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
} 