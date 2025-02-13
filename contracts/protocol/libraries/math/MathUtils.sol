// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import "./WadRayMath.sol";

library MathUtils {
    using WadRayMath for uint256;
      // Constants
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    uint256 internal constant SECONDS_PER_DAY = 86400;
    uint256 internal constant DAYS_PER_YEAR = 365;
    uint256 internal constant BASIS_POINTS = 10000;
    uint256 internal constant GRACE_PERIOD_DAYS = 15;
    uint256 internal constant LATE_FEE_BPS = 500; // 5% late fee

     /**
   * @dev Function to calculate the interest accumulated using a linear interest rate formula
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate linearly accumulated during the timeDelta, in ray
   **/
  function calculateLinearInterest(uint256 rate, uint40 lastUpdateTimestamp)
    internal
    view
    returns (uint256)
  {
    //solium-disable-next-line
    uint256 result = rate * (block.timestamp - uint256(lastUpdateTimestamp));
    unchecked {
      result = result / SECONDS_PER_YEAR;
    }

    return WadRayMath.RAY + result;
  }
}