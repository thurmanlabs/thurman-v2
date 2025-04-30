// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {Types} from "../protocol/libraries/types/Types.sol";

interface ILoanManager {
    function createLoan(
        address borrower,
        address originator,
        uint256 retentionRate,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) external returns (Types.Loan memory loan);

    function processRepayment(
        uint256 assets,
        address caller,
        address onBehalfOf,
        uint256 loanId
    ) external returns (uint256 remainingInterest, uint256 interestRate);

    function getLoan(address borrower, uint256 loanId) 
        external view returns (Types.Loan memory);
        
    function calculateMonthlyPayment(
        uint256 principal,
        uint256 interestRate,
        uint16 termMonths
    ) external pure returns (uint256);
}
