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
        /// @dev Principal amount of the loan
        uint256 principal;
        /// @dev Interest rate of the loan
        uint256 interestRate;
        /// @dev Term of the loan in months
        uint16 termMonths;
        /// @dev Next payment date
        uint40 nextPaymentDate;
        /// @dev Remaining balance of the loan
        uint256 remainingBalance;
        /// @dev Current payment index
        uint16 currentPaymentIndex;
        /// @dev Monthly payment amount
        uint256 monthlyPayment;
        /// @dev Status of the loan
        Status status;
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
        address vault;
        mapping(address borrower => Loan[]) loans;
    }
}
