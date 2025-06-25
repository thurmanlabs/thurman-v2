// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

library Types {
    struct ReserveData {
        /// @dev Stores the reserve configuration
        ReserveConfigurationMap configuration;
        /// @dev The liquidity index. Expressed in ray
        uint128 liquidityIndex;
        /// @dev The current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        /// @dev Variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        /// @dev The current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        /// @dev The current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        /// @dev Timestamp of last update
        uint40 lastUpdateTimestamp;
        /// @dev The id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        /// @dev The address of the aToken
        address aTokenAddress;
        /// @dev The address of the stable debt token
        address stableDebtTokenAddress;
        /// @dev The address of the variable debt token
        address variableDebtTokenAddress;
        /// @dev The address of the interest rate strategy
        address interestRateStrategyAddress;
        /// @dev The current treasury balance, scaled
        uint128 accruedToTreasury;
        /// @dev The outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        /// @dev The outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60: asset is paused
        //bit 61: borrowing in isolation mode is enabled
        //bit 62: siloed borrowing enabled
        //bit 63: flashloaning enabled
        //bit 64-79: reserve factor
        //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
        //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
        //bit 152-167 liquidation protocol fee
        //bit 168-175 eMode category
        //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
        //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
        //bit 252-255 unused

        uint256 data;
    }

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
        uint176 currentBorrowerIndex; // 176 bits

        // Slot 6: Aave balance (256 bits)
        uint256 aaveBalance;        // Full slot
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
        /// @dev The address of the aave pool
        address aavePool;
        /// @dev The address of the originator registry
        address originatorRegistry;
        /// @dev The ltv ratio of Thurman's aave collateral and borrows
        uint256 ltvRatio;
        /// @dev The accrued to treasury
        uint256 accruedToTreasury;
        /// @dev The margin fee accrued to treasury
        uint256 marginFee;
        /// @dev The last update timestamp of the liquidity premium index
        uint40 lastUpdateTimestamp;
        /// @dev The liquidity premium index
        uint256 liquidityPremiumIndex;
    }

    struct PoolConfig {
        /// @dev The ltv ratio cap
        uint256 ltvRatioCap;
        /// @dev The collateral cushion for individual loans expressed in ray
        uint256 collateralCushion;
        /// @dev The margin fee accrued to treasury
        uint256 marginFee;
        /// @dev The liquidity premium rate
        uint256 liquidityPremiumRate;
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
}
