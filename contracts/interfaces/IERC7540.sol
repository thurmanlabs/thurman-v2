// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Types} from "../protocol/libraries/types/Types.sol";

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

    event RedeemRequest(
        address indexed controller, 
        address indexed owner, 
        uint256 indexed requestId, 
        address sender, 
        uint256 shares
    );

    event RedeemClaimable(
        address indexed controller, 
        uint256 indexed requestId, 
        uint256 assets, 
        uint256 shares
    );

    event LoanInitialized(
        uint256 indexed loanId, 
        address indexed borrower, 
        uint256 principal, 
        uint16 termMonths, 
        uint256 interestRate
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
     * @dev Deposits exactly shares Vault shares to receiver by claiming the Request of the controller.
     *
     * - MUST emit the Deposit event.
     * - controller MUST equal msg.sender unless the controller has approved the msg.sender as an operator.
     *
     * @param assets the amount of assets to mint
     * @param receiver the address that will receive the shares
     * @param controller the controller who must approve the mint
     * @return shares the amount of shares taken from sender
     */
    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares);

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
     * @dev Fulfills a deposit request for a given pool.
     *
     * @param assets the amount of deposit assets to transfer from owner
     * @param receiver the address that will receive the shares
     */
    function fulfillDepositRequest(uint256 assets, address receiver) external returns (uint256 requestId);

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

    /**
     * @dev Assumes control of shares from sender into the Vault and submits a Request for asynchronous redeem.
     *
     * - MUST support a redeem Request flow where the control of shares is taken from sender directly
     *   where msg.sender has ERC-20 approval over the shares of owner.
     * - MUST revert if all of shares cannot be requested for redeem.
     *
     * @param assets the amount of assets to be redeemed to transfer from owner
     * @param controller the controller of the request who will be able to operate the request
     * @param owner the source of the shares to be redeemed
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault's share token.
     */
    function requestRedeem(
        uint256 assets, 
        address controller, 
        address owner
    ) external returns (uint256 requestId);

    /**
     * @dev Fulfills a redeem request for a given pool.
     *
     * @param assets the amount of assets to be redeemed
     * @param receiver the address that will receive the assets
     */
    function fulfillRedeemRequest(
        uint256 assets,
        address receiver
    ) external returns (uint256 requestId);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * @param assets the amount of assets to be redeemed
     * @param controller the controller of the request who will be able to operate the request
     * @param owner the source of the shares to be redeemed
     * @return shares the amount of shares to be transferred to receiver
     */
    function redeem(uint256 assets, address controller, address owner) external returns (uint256 shares);

    /**
     * @dev Returns the amount of requested assets in Pending state.
     *
     * @param requestId the ID of the redeem request
     * @param controller the controller address that must approve the redeem
     * @return pendingAssets amount of assets pending approval
     */
    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 pendingAssets);

    /**
     * @dev Returns the amount of requested assets in Claimable state for the controller to redeem.
     *
     * @param requestId the ID of the redeem request
     * @param controller the controller address that approved the redeem
     * @return claimableAssets amount of assets approved for redeem
     */
    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 claimableAssets);
    
    /**
     * @dev Initializes a loan for a borrower.
     *
     * @param borrower the address of the borrower
     * @param principal the principal amount of the loan
     * @param termMonths the term of the loan in months
     * @param interestRate the interest rate of the loan
     */
    function initLoan(
        address borrower, 
        uint256 principal, 
        uint16 termMonths,
        uint256 interestRate
    ) external;

    /**
     * @dev Repays a loan for a given borrower.
     *
     * @param assets the amount of assets to repay
     * @param onBehalfOf the address of the borrower
     * @param loanId the ID of the loan
     */
    function repay(
        uint256 assets, 
        address onBehalfOf,
        uint256 loanId
    ) external;

    /**
     * @dev Returns the address of the share token.
     *
     * @return share the address of the share token
     */
    function getShare() external view returns (address);

    /**
     * @dev Returns the user vault data for a given user.
     *
     * @param user the address of the user
     * @return userVaultData the user vault data
     */
    function getUserVaultData(address user) external view returns (Types.UserVaultData memory);

    /**
     * @dev Converts assets to shares.
     *
     * @param assets the amount of assets to convert
     * @return shares the amount of shares
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @dev Converts shares to assets.
     *
     * @param shares the amount of shares to convert
     * @return assets the amount of assets
     */
    function convertToAssets(uint256 shares) external view returns (uint256);
}



