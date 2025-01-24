// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

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
    function requestDeposit(uint16 poolId, uint256 assets) external returns (bool);

    /**
     * @dev Fulfills a deposit request for a given pool.
     *
     * @param poolId the id of the pool to deposit into
     * @param assets the amount of deposit assets to transfer from owner
     * @param receiver the address that will receive the shares
     */
    function fulfillDepositRequest(uint16 poolId, uint256 assets, address receiver) external returns (bool);

    /**
     * @dev Processes an owner's asset deposits after a successful fulfilled deposit by an operator.
     *
     * @param poolId the id of the pool to deposit into
     * @param assets the amount of deposit assets to transfer from owner
     * @param owner the address that will receive the shares
     */
    function deposit(uint16 poolId, uint256 assets, address owner) external returns (bool);
}