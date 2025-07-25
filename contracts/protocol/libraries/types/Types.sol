// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

library Types {
    struct UserVaultData {
        /// @dev Shares that can be claimed using `mint()`
        uint128 maxMint;
        /// @dev Assets that can be claimed using `withdraw()`
        uint128 maxWithdraw;
        /// @dev Remaining deposit request in assets
        uint128 pendingDepositRequest;
        /// @dev Remaining redeem request in shares
        uint128 pendingRedeemRequest;
    }

    struct Loan {
        // Slot 1: Core loan data (256 bits)
        uint96 id;                  // 96 bits
        uint16 termMonths;          // 16 bits
        uint16 currentPaymentIndex; // 16 bits
        Status status;              // 8 bits
        // 24 bits padding

        // Slot 2: Principal and balance (256 bits)
        uint128 principal;          // 128 bits

        // Slot 3: Rates (256 bits)
        uint128 interestRate;  // 128 bits

        // Slot 4: Payments (256 bits)
        uint128 remainingMonthlyPayment; // 128 bits

        // Slot 5: Timestamps and index (256 bits)
        uint40 nextPaymentDate;     // 40 bits
        uint40 lastUpdateTimestamp; // 40 bits

        /// @dev The address of the originator of the loan
        address originator;
        /// @dev The amount of interest retained by the originator
        uint256 retentionRate;
    }

    enum Status {
        /// @dev Loan is active
        Active,
        /// @dev Loan is defaulted
        Defaulted,
        /// @dev Loan is closed
        Closed
    }   

    struct PaymentBreakdown {
        /// @dev Total payment amount
        uint256 paymentAmount;
        /// @dev Principal portion of the payment
        uint256 principalPortion;
        /// @dev Interest portion of the payment
        uint256 interestPortion;
        /// @dev Remaining balance after payment
        uint256 remainingBalance;
    }

    struct Pool {
        /// @dev The address of the pool config
        PoolConfig config;
        /// @dev The address of the vault
        address vault;
        /// @dev The address of the originator registry
        address originatorRegistry;
        /// @dev The accrued to treasury
        uint256 accruedToTreasury;
        /// @dev The margin fee accrued to treasury
        uint256 marginFee;
        /// @dev The cumulative distributions of payments to LPs per share
        uint256 cumulativeDistributionsPerShare;
        /// @dev The last timestamp of a distribution of payments to LPs
        uint40 lastDistributionTimestamp;
        /// @dev The total principal originated per pool
        uint256 totalPrincipal;
        /// @dev The total deposits to the pool
        uint256 totalDeposits;
    }

    struct PoolConfig {
        /// @dev Toggle deposit operations
        bool depositsEnabled;
        /// @dev Toggle withdrawal operations
        bool withdrawalsEnabled;
        /// @dev Toggle loan initiation
        bool borrowingEnabled;
        /// @dev Emergency pause all operations
        bool isPaused;
        /// @dev Maximum single deposit limit
        uint256 maxDepositAmount;
        /// @dev Minimum single deposit limit
        uint256 minDepositAmount;
        /// @dev Total pool size limit
        uint256 depositCap;
    }

    struct MonthlyPaymentVars {
        uint256 monthlyRate;
        uint256 rateFactor;
        uint256 rateFactorPower;
        uint256 principalRay;
    }

    // Batch loan initialization struct
    struct BatchLoanData {
        address borrower;
        uint256 retentionRate;
        uint256 principal;
        uint16 termMonths;
        uint256 interestRate;
    }

    struct BatchRepaymentData {
        address borrower;
        uint256 loanId;
        uint256 paymentAmount;
    }
}
