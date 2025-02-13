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
        /// @dev Loan ID
        uint256 id;
        /// @dev collateral allocated to the loan
        uint256 collateralAllocated;
        /// @dev Principal amount of the loan
        uint256 principal;
        /// @dev Annual interest rate in ray
        uint256 projectedLossRate;
        /// @dev Annual interest rate in ray
        uint256 interestRate;
        /// @dev Term of the loan in months
        uint16 termMonths;
        /// @dev Next payment date
        uint40 nextPaymentDate;
        /// @dev Remaining balance of the loan
        uint256 remainingBalance;
        /// @dev Remaining balance in aave
        uint256 aaveBalance;
        /// @dev Current payment index
        uint16 currentPaymentIndex;
        /// @dev Monthly payment amount
        uint256 monthlyPayment;
        /// @dev Remaining monthly payment
        uint256 remainingMonthlyPayment;
        /// @dev Status of the loan
        Status status;
        /// @dev Aave's current variable borrower index
        uint256 currentBorrowerIndex;
        /// @dev Timestamp of last update
        uint40 lastUpdateTimestamp;
        
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
        /// @dev The address of the vault
        address vault;
        /// @dev The address of the aave pool
        address aavePool;
        /// @dev The address of the underlying asset
        address underlyingAsset;
        /// @dev The address of the aave aToken
        address aToken;
        /// @dev The address of the variable debt token
        address variableDebtToken;
        /// @dev The address of the sToken
        address sToken;
        /// @dev The balance of the aave collateral
        uint256 aaveCollateralBalance;
        /// @dev The balance of the aave borrow
        uint256 aaveBorrowBalance;
        /// @dev The base interest rate of loans in the pool
        uint256 baseRate;
        /// @dev The ltv ratio
        uint256 ltvRatio;
        /// @dev The ltv ratio cap
        uint256 ltvRatioCap;
        /// @dev The collateral cushion for individual loans expressed in ray
        uint256 collateralCushion;
        /// @dev The amount guaranteed by the pool
        uint256 amountGuaranteed;
        /// @dev The accrued to treasury
        uint256 accruedToTreasury;
        /// @dev The margin fee accrued to treasury
        uint256 marginFee;
        /// @dev The liquidity premium index added on top of Aave yield
        uint256 liquidityPremiumIndex;
        /// @dev The liquidity premium rate
        uint256 liquidityPremiumRate;
        /// @dev The last update timestamp of the liquidity premium index
        uint40 lastUpdateTimestamp;
    }
}
