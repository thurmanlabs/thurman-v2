// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IAToken is IERC20 {
    /**
   * @notice Returns the scaled balance of the user.
   * @dev The scaled balance is the sum of all the updated stored balance divided by the reserve's liquidity index
   * at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   */
  function scaledBalanceOf(address user) external view returns (uint256);
}