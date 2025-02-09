// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {Types} from "../types/Types.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
library Deposit {
    using WadRayMath for uint256;

    function requestDeposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address controller,
        address owner
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.requestDeposit(assets, controller, owner);
    }

    function fulfillDeposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.fulfillDepositRequest(assets, receiver);
        IAToken aToken = IAToken(pool.aToken);
        uint256 aaveCollateralBalance = aToken.balanceOf(pool.vault);
        pool.aaveCollateralBalance = aaveCollateralBalance;
        uint256 ltvRatio = pool.aaveBorrowBalance.rayDiv(aaveCollateralBalance);
        pool.ltvRatio = ltvRatio;
    }

    function deposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address owner
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.deposit(assets, owner, owner);
    }

    function requestRedeem(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address controller,
        address owner
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        uint256 shares = vault.convertToShares(assets);
        vault.requestRedeem(shares, controller, owner);
    }

    function fulfillRedeem(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        uint256 shares = vault.convertToShares(assets);
        vault.fulfillRedeemRequest(shares, receiver);
        IAToken aToken = IAToken(pool.aToken);
        uint256 aaveBorrowBalance = aToken.balanceOf(pool.variableDebtToken);
        pool.aaveBorrowBalance = aaveBorrowBalance;
        uint256 ltvRatio = pool.aaveBorrowBalance.rayDiv(pool.aaveCollateralBalance);
        pool.ltvRatio = ltvRatio;
    }

    function redeem(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.redeem(assets, msg.sender, receiver);
    }
}
