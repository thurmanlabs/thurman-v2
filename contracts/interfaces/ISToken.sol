// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISToken is IERC20 {
  event Mint(
    address indexed caller,
    address indexed onBehalfOf,
    uint256 value
  );

  event Burn(
    address indexed from,
    address indexed receiverOfUnderlying,
    uint256 value
  );
  
    /**
   * @notice Mints `amount` sTokens to `user` based on underlying aToken logic
   * @param caller The address performing the mint
   * @param onBehalfOf The address of the user that will receive the minted aTokens
   * @param amount The amount of tokens getting minted
   * @return `true` if the the previous balance of the user was 0
   */
  function mint(
    address caller,
    address onBehalfOf,
    uint256 amount
  ) external returns (bool);

  function mintToTreasury(uint256 amount, uint256 index) external;

  /**
   * @notice Burns sTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
   * @dev In some instances, the mint event could be emitted from a burn transaction
   * if the amount to burn is less than the interest that the user accrued
   * @param from The address from which the aTokens will be burned
   * @param receiverOfUnderlying The address that will receive the underlying
   * @param amount The amount being burned
   */
  function burn(
    address from, 
    address receiverOfUnderlying, 
    uint256 amount
  ) external;

  /**
   * @notice Transfers the underlying assets to the originator
   * @param amount The amount of underlying assets to transfer
   * @param originator The address of the originator
   */
  function transferUnderlyingToOriginator(uint256 amount, address originator) external;

  /**
   * @notice Returns the total claimable returns for a user
   * @param user The address of the user
   * @return The total claimable returns
   */
  function totalClaimableReturns(address user) external view returns (uint256);

  /**
   * @notice Returns the user baseline for a user
   * @param user The address of the user
   * @return The user baseline
   */
  function getUserBaseline(address user) external view returns (uint256);
}
