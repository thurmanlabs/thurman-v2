// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Types} from "../protocol/libraries/types/Types.sol";

interface IPoolManager {
    event PoolAdded(uint16 indexed poolId, address indexed vault, address indexed underlyingAsset);
    event MintedToTreasury(uint16 indexed poolId, uint256 amountMinted);
    
    /**
     * @dev Sets the operator for the pool manager
     * @param poolId The ID of the pool to set the operator for
     * @param operator The address of the operator
     * @param approved The approval status
     */
    function setOperator(uint16 poolId, address operator, bool approved) external;

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
     * @param controller the address that will receive the shares
     * NOTE: most implementations will require pre-approval of the Vault with the Vault's underlying asset token.
     */
    function requestDeposit(uint16 poolId, uint256 assets, address controller) external;

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
     * @dev Initializes a loan for a given pool.
     *
     * @param poolId the id of the pool to initialize the loan for
     * @param borrower the address of the borrower
     * @param originator the address of the originator
     * @param retentionRate the retention rate of the loan
     * @param principal the principal amount of the loan
     * @param termMonths the term of the loan in months
     * @param interestRate the interest rate of the loan
     */
    function initLoan(
        uint16 poolId, 
        address borrower, 
        address originator,
        uint256 retentionRate,
        uint256 principal, 
        uint16 termMonths, 
        uint256 interestRate
    ) external;

    /**
     * @dev Repays a loan for a given borrower.
     *
     * @param poolId the id of the pool to repay the loan for
     * @param assets the amount of assets to repay
     * @param onBehalfOf the address of the borrower
     * @param loanId the ID of the loan
     */
    function repayLoan(
        uint16 poolId,
        uint256 assets, 
        address onBehalfOf,
        uint256 loanId
    ) external;

    /**
    * @dev Adds a new pool to the pool manager
    * @param vault The address of the vault to add
    * @param collateralCushion The collateral cushion for the pool
    * @param ltvRatioCap The ltv ratio cap for the pool
    * @param liquidityPremiumRate The liquidity premium rate for the pool
    * @param marginFee The margin fee for the pool
    */
    function addPool(
        address vault,
        address aavePool,
        uint256 collateralCushion,
        uint256 ltvRatioCap,
        uint256 liquidityPremiumRate,
        uint256 marginFee
    ) external;

    /**
     * @dev Mints sTokens to the treasury
     * @param poolId The ID of the pool to mint to
     * @param amount The amount of sTokens to mint
     */
    function mintToTreasury(uint16 poolId, uint256 amount) external;

    /**
     * @dev Returns boolean telling if the address is the owner of the pool manager
     * @param _address The address to check
     * @return bool True if the address is the owner, false otherwise
     */
    function isOwner(address _address) external view returns (bool);

    /**
     * @dev Returns the pool for a given pool id
     * @param poolId The ID of the pool to get
     * @return pool The pool for the given id
     */
    function getPool(uint16 poolId) external view returns (Types.Pool memory);

    /**
     * @dev Returns the number of pools in the pool manager
     * @return poolCount The number of pools in the pool manager
     */
    function getPoolCount() external view returns (uint16);

    /**
     * @dev Returns the normalized return for a given pool
     * @param poolId The ID of the pool to get the normalized return for
     * @return normalizedReturn The normalized return for the pool
     */
    function getNormalizedReturn(uint16 poolId) external view returns (uint256);
}
