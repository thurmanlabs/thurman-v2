// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Types} from "../types/Types.sol";

library Validation {
    function validateSetOperator(address operator) internal view {
        require(operator != msg.sender, "ERC7540Vault/cannot-set-self-as-operator");
    }

    function validateController(
        address controller, 
        mapping(address => mapping(address => bool)) storage isOperator
    ) internal view {
        require(controller == msg.sender || isOperator[msg.sender][controller], "ERC7540Vault/invalid-controller");
    }

    function validateRequestDeposit(
        address vaultAddress,
        uint256 assets) internal view {
        IERC7540Vault vault = IERC7540Vault(vaultAddress);
        require(assets > 0, "ERC7540Vault/invalid-assets");
        require(assets <= IERC20(vault.asset()).balanceOf(msg.sender), "ERC7540Vault/insufficient-assets");
    }

    function validateFulfilledDepositRequest(
        Types.UserVaultData memory userVaultData
    ) internal pure {
        require(userVaultData.pendingDepositRequest != 0, "ERC7540Vault/no-pending-deposit-request");
    }
}
