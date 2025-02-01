// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {Types} from "../types/Types.sol";
library Deposit {
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
