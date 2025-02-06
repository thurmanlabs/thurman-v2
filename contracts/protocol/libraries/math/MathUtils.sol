// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import "./WadRayMath.sol";

library MathUtils {
    using WadRayMath for uint256;
      // Constants
    uint256 internal constant SECONDS_PER_DAY = 86400;
    uint256 internal constant DAYS_PER_YEAR = 365;
    uint256 internal constant BASIS_POINTS = 10000;
    uint256 internal constant GRACE_PERIOD_DAYS = 15;
    uint256 internal constant LATE_FEE_BPS = 500; // 5% late fee
}