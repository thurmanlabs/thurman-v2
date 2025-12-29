// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {ILoanManager} from "../../interfaces/ILoanManager.sol";
import {Types} from "../libraries/types/Types.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {LoanMath} from "../libraries/math/LoanMath.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {DateTime} from "@quant-finance/solidity-datetime/contracts/DateTime.sol";

contract LoanManager is Initializable, OwnableUpgradeable, ILoanManager {
    using WadRayMath for uint256;
    using SafeCast for uint256;

        /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() external virtual initializer {
        __Ownable_init(msg.sender);
    }

    
    function createLoan(
        uint256 loanId,
        address originator,
        uint256 retentionRate,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) external view returns (Types.Loan memory loan) {
        uint256 payment = LoanMath.calculateMonthlyPayment(
            principal,
            interestRate,
            termMonths
        );
        
        // Calculate first payment date as same calendar day next month
        uint256 firstPaymentDate = DateTime.addMonths(block.timestamp, 1);
        
        loan = Types.Loan({
            id: uint96(loanId),
            principal: uint128(principal),
            interestRate: uint128(interestRate),
            termMonths: termMonths,
            nextPaymentDate: uint40(firstPaymentDate),
            remainingMonthlyPayment: uint128(payment),
            currentPaymentIndex: 0,
            status: Types.Status.Active,
            lastUpdateTimestamp: uint40(block.timestamp),
            originator: originator,
            retentionRate: retentionRate
        });

        return loan;
    }

    function processRepayment(
        Types.Loan memory loan,
        uint256 assets,
        uint8 assetDecimals
    ) external view returns (
        Types.Loan memory updatedLoan,
        uint256 principalPortion,
        uint256 interestPortion,
        uint256 remainingInterest
    ) {
        require(loan.status == Types.Status.Active, "LoanManager/loan-not-active");

        uint256 remainingBalance = loan.principal;
        require(remainingBalance > 0, "LoanManager/loan-fully-repaid");

        uint256 currentTimestamp = block.timestamp;

        uint256 totalInterestDue = LoanMath.calculateMonthlyInterest(loan, remainingBalance, assetDecimals);

        // Interest always gets paid first
        uint256 scheduledPayment = loan.remainingMonthlyPayment;
        interestPortion = (assets >= totalInterestDue) ? totalInterestDue : assets;

        // Remaining payment goes to principal
        principalPortion = assets - interestPortion;
        
        // Ensure we don't repay more than the remaining balance
        if (principalPortion > remainingBalance) {
            principalPortion = remainingBalance;
            // Adjust total payment to match what's actually being applied
            assets = interestPortion + principalPortion;
        }

        // Update loan state
        loan.principal = uint128(remainingBalance - principalPortion);
        
        if (assets >= scheduledPayment) {
            // Full or excess payment - reset monthly payment and advance next payment date
            loan.remainingMonthlyPayment = 0;
            loan.nextPaymentDate = uint40(
                _getNextPaymentDate(loan.nextPaymentDate)
            );
            loan.currentPaymentIndex++;
        } else {
            // Partial payment - reduce remaining monthly payment
            loan.remainingMonthlyPayment = uint128(scheduledPayment - assets);
        }
        
        loan.lastUpdateTimestamp = uint40(currentTimestamp);
        
        // Check if loan is fully paid
        if (loan.principal == 0) {
            loan.status = Types.Status.Closed;
        }
        
        // Return values needed by the vault
        remainingInterest = totalInterestDue - interestPortion;
        return (loan, principalPortion, interestPortion, remainingInterest);
        
    }

    /**
    * @notice Calculate the next payment date using calendar-month arithmetic
    * @dev Uses BokkyPooBahsDateTimeLibrary for proper date handling.
    *      This ensures payments fall on the same calendar day each month,
    *      which is standard for CDFI and traditional bank loans.
    *      Example: Jan 15 -> Feb 15 -> Mar 15 (handles month-end correctly)
    * @param currentPaymentDate The current payment date timestamp
    * @return nextPaymentDate The timestamp for the next payment (same calendar day, next month)
    */
    function _getNextPaymentDate(uint40 currentPaymentDate) internal pure returns (uint256) {
        return DateTime.addMonths(currentPaymentDate, 1);
    }
}