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
        
        loan = Types.Loan({
            id: uint96(loanId),
            principal: uint128(principal),
            interestRate: uint128(interestRate),
            termMonths: termMonths,
            nextPaymentDate: uint40(block.timestamp + 30 days),
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
        uint256 assets
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

        uint256 totalInterestDue = LoanMath.calculateMonthlyInterest(loan, remainingBalance);

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

        // 3. Update loan state
        if (assets >= scheduledPayment) {
            // Full or excess payment - reset monthly payment and advance next payment date
            loan.remainingMonthlyPayment = 0;
            loan.nextPaymentDate = uint40(
                loan.nextPaymentDate + _calculateDaysToNextPayment(loan.nextPaymentDate) * 1 days
            );
            loan.currentPaymentIndex++;
        } else {
            // Partial payment - reduce remaining monthly payment
            loan.remainingMonthlyPayment = uint128(scheduledPayment - assets);
        }
        
        loan.lastUpdateTimestamp = uint40(currentTimestamp);
        
        // 6. Check if loan is fully paid
        if (remainingBalance == principalPortion) {
            loan.status = Types.Status.Closed;
        }
        
        // Return values needed by the vault
        remainingInterest = totalInterestDue - interestPortion;
        return (loan, principalPortion, interestPortion, remainingInterest);
        
    }

    /**
    * @notice Calculate how many days until the next payment date
    * @param nextPaymentDate The current next payment date timestamp
    * @return days The number of days until next payment
    */
    function _calculateDaysToNextPayment(uint40 nextPaymentDate) internal view returns (uint256) {
        // If payment date is in the past, use standard 30 days
        if (nextPaymentDate <= block.timestamp) {
            return 30;
        }
        
        // Get current date components
        uint256 currentYear = block.timestamp / (365 days);
        uint256 currentMonth = (block.timestamp % (365 days)) / (30 days);
        
        // Calculate days in the current month (simplified version)
        uint8[12] memory daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        
        // Adjust February for leap years
        if (currentMonth == 1 && _isLeapYear(currentYear)) {
            daysInMonth[1] = 29;
        }
        
        return daysInMonth[currentMonth];
    }

    /**
    * @notice Check if a year is a leap year
    * @param year The year to check
    * @return True if leap year
    */
    function _isLeapYear(uint256 year) internal pure returns (bool) {
        return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
    }

    /**
    * @notice Calculate the amount to repay to Aave
    * @param principalPortion Principal being repaid
    * @param balanceIncrease Interest accrued from Aave's variable rate
    * @param currentAaveBalance Current balance owed to Aave
    * @return The amount to repay to Aave
    */
    function _calculateAaveRepaymentAmount(
        uint256 principalPortion,
        uint256 balanceIncrease,
        uint256 currentAaveBalance
    ) internal pure returns (uint256) {
        // Always repay accrued interest to Aave
        uint256 aavePaymentAmount = balanceIncrease;
        
        // Add principal payment
        aavePaymentAmount += principalPortion;
        
        // Ensure we don't try to repay more than owed to Aave
        if (aavePaymentAmount > currentAaveBalance + balanceIncrease) {
            aavePaymentAmount = currentAaveBalance + balanceIncrease;
        }
        
        return aavePaymentAmount;
    }
}