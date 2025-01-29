// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";

library Deposit {
    function requestDeposit(
        mapping(uint16 => address) storage pools,
        uint16 poolId,
        uint256 assets,
        address controller,
        address owner
    ) internal {
        address pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool);
        vault.requestDeposit(assets, controller, owner);
    }

    function fulfillDeposit(
        mapping(uint16 => address) storage pools,
        uint16 poolId,
        uint256 assets,
        uint256 shares,
        address receiver
    ) internal {
        address pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool);
        vault.fulfillDepositRequest(assets, shares, receiver);
    }

    function deposit(
        mapping(uint16 => address) storage pools,
        uint16 poolId,
        uint256 assets,
        address owner
    ) internal {
        address pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool);
        vault.requestDeposit(assets, msg.sender, owner);
    }

    function requestRedeem(
        mapping(uint16 => address) storage pools,
        uint16 poolId,
        uint256 shares,
        address controller,
        address owner
    ) internal {
        address pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool);
        vault.requestRedeem(shares, controller, owner);
    }

    function fulfillRedeem(
        mapping(uint16 => address) storage pools,
        uint16 poolId,
        uint256 shares,
        uint256 assets,
        address receiver
    ) internal {
        address pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool);
        vault.fulfillRedeemRequest(shares, assets, receiver);
    }

    function redeem(
        mapping(uint16 => address) storage pools,
        uint16 poolId,
        uint256 shares,
        address receiver
    ) internal {
        address pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool);
        vault.redeem(shares, msg.sender, receiver);
    }
}
