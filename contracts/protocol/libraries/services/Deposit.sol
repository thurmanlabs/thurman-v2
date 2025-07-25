// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {Types} from "../types/Types.sol";
import {WadRayMath} from "../math/WadRayMath.sol";

library Deposit {
    using WadRayMath for uint256;

    function setOperator(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        address operator,
        bool approved
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.setOperator(operator, approved);
    }
    
    function requestDeposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address controller,
        address owner
    ) internal {
        Types.Pool memory pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        address sTokenAddress = vault.getShare();
        ISToken sToken = ISToken(sTokenAddress);
        uint256 currentAssets = IERC20(sToken.asset()).balanceOf(sTokenAddress);
        Validation.validateRequestDeposit(pool, owner, assets, currentAssets);
        vault.requestDeposit(assets, controller, owner);
    }

    function fulfillDeposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.Pool memory pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        uint256 pendingDepositRequest = vault.pendingDepositRequest(receiver);
        Validation.validateFulfillDepositRequest(pool, assets, pendingDepositRequest);
        pool.totalDeposits += assets;
        vault.fulfillDepositRequest(assets, receiver);
    }

    function deposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address owner
    ) internal {
        Types.Pool memory pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        address sTokenAddress = vault.getShare();
        ISToken sToken = ISToken(sTokenAddress);
        uint256 currentAssets = IERC20(sToken.asset()).balanceOf(sTokenAddress);
        uint256 maxMint = vault.userVaultData(owner).maxMint;
        Validation.validateDeposit(pool, assets, currentAssets, maxMint);
        vault.deposit(assets, owner, owner);
    }

    function requestRedeem(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address controller,
        address owner
    ) internal {
        Types.Pool memory pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        address sToken = vault.getShare();
        uint256 shares = vault.convertToShares(assets);
        Validation.validateRequestRedeem(pool, sToken, assets, shares, owner);
        vault.requestRedeem(shares, controller, owner);
    }

    function fulfillRedeem(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.Pool memory pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        uint256 shares = vault.convertToShares(assets);
        uint256 pendingRedeemRequest = vault.pendingRedeemRequest(receiver);
        Validation.validateFulfillRedeemRequest(pool, shares, pendingRedeemRequest);
        vault.fulfillRedeemRequest(shares, receiver);
    }

    function redeem(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.Pool memory pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        uint256 claimableAmount = vault.claimableRedeemRequest(0, receiver);
        uint256 pendingRedeemRequest = vault.pendingRedeemRequest(receiver);
        uint256 maxWithdraw = vault.userVaultData(receiver).maxWithdraw;
        Validation.validateRedeem(pool, claimableAmount, pendingRedeemRequest, maxWithdraw, assets);
        vault.redeem(assets, msg.sender, receiver);
    }
}
