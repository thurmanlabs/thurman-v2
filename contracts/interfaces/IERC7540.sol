// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IERC7540Vault is IERC4626 {
    /**
     * @dev The event emitted when an operator is set.
     *
     * @param controller The address of the controller.
     * @param operator The address of the operator.
     * @param approved The approval status.
     */
    event OperatorSet(address indexed controller, address indexed operator, bool approved);
    
    event DepositRequest(
        address indexed controller, 
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 assets
    );

    event DepositClaimable(
        address indexed controller, 
        uint256 indexed requestId, 
        uint256 assets, 
        uint256 shares
    );

    /**
     * @dev Sets or removes an operator for the caller.
     *
     * @param operator The address of the operator.
     * @param approved The approval status.
     * @return Whether the call was executed successfully or not
     */
    function setOperator(address operator, bool approved) external returns (bool);

    /**
     * @dev Returns `true` if the `operator` is approved as an operator for an `controller`.
     *
     * @param controller The address of the controller.
     * @param operator The address of the operator.
     * @return status The approval status
     */
    function isOperator(address controller, address operator) external view returns (bool status);

    /**
     * @dev Mints exactly shares Vault shares to receiver by claiming the Request of the controller.
     *
     * - MUST emit the Deposit event.
     * - controller MUST equal msg.sender unless the controller has approved the msg.sender as an operator.
     *
     * @param shares the amount of shares to mint
     * @param receiver the address that will receive the shares
     * @param controller the controller who must approve the mint
     * @return assets the amount of assets taken from sender
     */
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    /**
     * @dev Transfers assets from sender into the Vault and submits a Request for asynchronous deposit.
     *
     * - MUST support ERC-20 approve / transferFrom on asset as a deposit Request flow.
     * - MUST revert if all of assets cannot be requested for deposit.
     * - owner MUST be msg.sender unless some unspecified explicit approval is given by the caller,
     *    approval of ERC-20 tokens from owner to sender is NOT enough.
     *
     * @param assets the amount of deposit assets to transfer from owner
     * @param controller the controller of the request who will be able to operate the request
     * @param owner the source of the deposit assets
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault's underlying asset token.
     */
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);

    /**
     * @dev Returns the amount of requested assets in Pending state.
     *
     * - MUST NOT include any assets in Claimable state for deposit or mint.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
     *
     * @param requestId the ID of the deposit request
     * @param controller the controller address that must approve the deposit
     * @return pendingAssets amount of assets pending approval
     */
    function pendingDepositRequest(uint256 requestId, address controller)
        external
        view
        returns (uint256 pendingAssets);

    /**
     * @dev Returns the amount of requested assets in Claimable state for the controller to deposit or mint.
     *
     * - MUST NOT include any assets in Pending state.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
     *
     * @param requestId the ID of the deposit request
     * @param controller the controller address that approved the deposit
     * @return claimableAssets amount of assets approved for deposit
     */
    function claimableDepositRequest(uint256 requestId, address controller) 
        external 
        view 
        returns (uint256 claimableAssets);
}

