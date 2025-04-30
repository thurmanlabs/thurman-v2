// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {Types} from "../protocol/libraries/types/Types.sol";

interface ILoanManager {
    

    /**
     * @dev Creates a new loan.
     *
     * @param borrower The address of the borrower.
     * @param originator The address of the originator.
     * @param retentionRate The retention rate of the loan.
     * @param principal The principal amount of the loan.
     * @param termMonths The term of the loan in months.
     * @param interestRate The interest rate of the loan.
     * @param currentBorrowerIndex The index of the current borrower.
     * @return loan The new loan.
     */
    function createLoan(
        address borrower,
        address originator,
        uint256 retentionRate,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate,
        uint256 currentBorrowerIndex
    ) external returns (Types.Loan memory loan);

    /**
     * @dev Processes a repayment.
     *
     * @param assets The amount of assets to repay.
     * @param onBehalfOf The address of the on behalf of.
     * @param loanId The id of the loan.    
     * @return principalPortion The principal portion.
     * @return interestPortion The interest portion.
     * @return remainingInterest The remaining interest.
     */
    function processRepayment(
        uint256 assets,
        address onBehalfOf,
        uint256 loanId
    ) external returns (uint256 principalPortion, uint256 interestPortion, uint256 remainingInterest);

    
    /**
     * @dev Gets a loan.
     *
     * @param borrower The address of the borrower.
     * @param loanId The id of the loan.
     * @return loan The loan.
     */
    function getLoan(address borrower, uint256 loanId) external view returns (Types.Loan memory);
        
}
