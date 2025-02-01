// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Types} from "../protocol/libraries/types/Types.sol";

interface IPoolManager {
    /**
     * @dev Transfers assets from sender into the Vault attached to the pool and submits a Request for asynchronous deposit.
     *
     * - MUST support ERC-20 approve / transferFrom on asset as a deposit Request flow.
     * - MUST revert if all of assets cannot be requested for deposit.
     * - owner MUST be msg.sender unless some unspecified explicit approval is given by the caller,
     *    approval of ERC-20 tokens from owner to sender is NOT enough.
     *
     * @param poolId the id of the pool to deposit into
     * @param assets the amount of deposit assets to transfer from owner
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault's underlying asset token.
     */
    function requestDeposit(uint16 poolId, uint256 assets) external;

    /**
     * @dev Fulfills a deposit request for a given pool.
     *
     * @param poolId the id of the pool to deposit into
     * @param assets the amount of deposit assets to transfer from owner
     * @param receiver the address that will receive the shares
     */
    function fulfillDeposit(uint16 poolId, uint256 assets, address receiver) external;

    /**
     * @dev Processes an owner's asset deposits after a successful fulfilled deposit by an operator.
     *
     * @param poolId the id of the pool to deposit into
     * @param assets the amount of deposit assets to transfer from owner
     * @param owner the address that will receive the shares
     */
    function deposit(uint16 poolId, uint256 assets, address owner) external;

    /**
     * @dev Requests a redeem for a given pool.
     *
     * @param poolId the id of the pool to redeem from
     * @param assets the amount of assets to redeem
     * @param controller the address that will receive the assets
     */
    function requestRedeem(uint16 poolId, uint256 assets, address controller, address owner) external;

    /**
     * @dev Fulfills a redeem request for a given pool.
     *
     * @param poolId the id of the pool to redeem from
     * @param assets the amount of assets to redeem
     * @param receiver the address that will receive the assets
     */
    function fulfillRedeem(uint16 poolId, uint256 assets, address receiver) external;

    /**
     * @dev Redeems shares for a given pool.
     *
     * @param poolId the id of the pool to redeem from
     * @param assets the amount of assets to redeem
     * @param receiver the address that will receive the assets
     */
    function redeem(uint16 poolId, uint256 assets, address receiver) external;

    /**
    * @dev Adds a new pool to the pool manager
    * @param vault The address of the vault to add
    */
    function addPool(address vault) external;

    /**
     * @dev Returns boolean telling if the address is the owner of the pool manager
     * @param _address The address to check
     * @return bool True if the address is the owner, false otherwise
     */
    function isOwner(address _address) external view returns (bool);

    function getPool(uint16 poolId) external view returns (Types.Pool memory);

    /**
     * @dev Connects the SToken to its corresponding vault
     * @param poolId The ID of the pool to connect
     */
    function connectSTokentoVault(uint16 poolId) external;
}
