// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

/**
 * @title WadRayMath library
 * @author Aave
 * @notice Provides functions to perform calculations with Wad and Ray units
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits of precision) and rays (decimal numbers
 * with 27 digits of precision)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 **/
library WadRayMath {
  // HALF_WAD and HALF_RAY expressed with extended notation as constant with operations are not supported in Yul assembly
  uint256 internal constant WAD = 1e18;
  uint256 internal constant HALF_WAD = 0.5e18;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant HALF_RAY = 0.5e27;

  uint256 internal constant WAD_RAY_RATIO = 1e9;

  /**
   * @dev Multiplies two wad, rounding half up to the nearest wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @param b Wad
   * @return c = a*b, in wad
   **/
  function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
    assembly {
      if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, b), HALF_WAD), WAD)
    }
  }

  /**
   * @dev Divides two wad, rounding half up to the nearest wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @param b Wad
   * @return c = a/b, in wad
   **/
  function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - halfB) / WAD
    assembly {
      if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, WAD), div(b, 2)), b)
    }
  }

  /**
   * @notice Multiplies two ray, rounding half up to the nearest ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @param b Ray
   * @return c = a raymul b
   **/
  function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Check for zero inputs
    if (b == 0) {
        return 0;
    }
    
    // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
    uint256 maxA = (type(uint256).max - HALF_RAY) / b;
    if (a > maxA) {
        revert("WadRayMath: rayMul overflow");
    }
    c = (a * b + HALF_RAY) / RAY;
    return c;
  }

  /**
   * @notice Divides two ray, rounding half up to the nearest ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @param b Ray
   * @return c = a raydiv b
   **/
  function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - halfB) / RAY
    assembly {
      if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, RAY), div(b, 2)), b)
    }
  }

  /**
   * @dev Raised to the power of n
   * @param x ray
   * @param n power
   * @return z = x^n, in ray
   **/
  function rayPow(uint256 x, uint256 n) internal pure returns (uint256 z) {
    z = n % 2 != 0 ? x : RAY;

    for (n /= 2; n != 0; n /= 2) {
      x = rayMul(x, x);

      if (n % 2 != 0) {
        z = rayMul(z, x);
      }
    }
  }

  /**
   * @dev Converts a wad to a ray
   * @param a Wad
   * @return b = a converted in ray
   **/
  function wadToRay(uint256 a) internal pure returns (uint256 b) {
    b = a * WAD_RAY_RATIO;
  }

  /**
   * @dev Converts a ray to a wad
   * @param a Ray
   * @return b = a converted in wad
   **/
  function rayToWad(uint256 a) internal pure returns (uint256 b) {
    b = a / WAD_RAY_RATIO;
  }

  /**
   * @dev Converts an amount from token decimals to WAD (18 decimals)
   * @param amount Amount in token decimals
   * @param decimals Token decimals
   * @return amount in WAD
   **/
  function toWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
    if (decimals == 18) return amount;
    require(decimals < 18, "WadRayMath: too many decimals");
    return amount * (10 ** (18 - decimals));
  }

  /**
   * @dev Converts an amount from WAD (18 decimals) to token decimals
   * @param wadAmount Amount in WAD
   * @param decimals Token decimals
   * @return amount in token decimals
   **/
  function fromWad(uint256 wadAmount, uint8 decimals) internal pure returns (uint256) {
    if (decimals == 18) return wadAmount;
    require(decimals < 18, "WadRayMath: too many decimals");
    return wadAmount / (10 ** (18 - decimals));
  }
}