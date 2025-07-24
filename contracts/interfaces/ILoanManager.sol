// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {Types} from "../protocol/libraries/types/Types.sol";

interface ILoanManager {
    

    /**
     * @dev Creates a new loan.
     *
     * @param originator The address of the originator.
     * @param retentionRate The retention rate of the loan.
     * @param principal The principal amount of the loan.
     * @param termMonths The term of the loan in months.
     * @param interestRate The interest rate of the loan.
     * @return loan The new loan.
     */
    function createLoan(
        uint256 loanId,
        address originator,
        uint256 retentionRate,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) external returns (Types.Loan memory loan);

    /**
     * @dev Processes a repayment.
     *
     * @param loan The loan to process.
     * @param vault The vault of the loan.
     * @param assets The amount of assets to repay.
     * @param onBehalfOf The address of the on behalf of.
     * @return updatedLoan The updated loan.
     * @return principalPortion The principal portion.
     * @return interestPortion The interest portion.
     * @return remainingInterest The remaining interest.
     */
    function processRepayment(
        Types.Loan memory loan,
        address vault,
        uint256 assets,
        address onBehalfOf
    ) external returns (
        Types.Loan memory updatedLoan, 
        uint256 principalPortion, 
        uint256 interestPortion, 
        uint256 remainingInterest
    );
        
}
