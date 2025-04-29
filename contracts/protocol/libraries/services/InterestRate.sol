// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {WadRayMath} from "../math/WadRayMath.sol";
import {Types} from "../types/Types.sol";
import {LoanMath} from "../math/LoanMath.sol";

library InterestRate {
    using WadRayMath for uint256;
    using LoanMath for uint256;

    function getCurrentMonthlyPayment(
        Types.Loan storage loan
    ) internal view returns (uint256, uint256) {
        // Check loan status (slot 1)
        uint256 currentMonthlyPayment = LoanMath.calculateMonthlyPayment(
            uint256(loan.principal),
            loan.interestRate,
            loan.termMonths
        );

        return (currentMonthlyPayment, loan.interestRate);
    }
}