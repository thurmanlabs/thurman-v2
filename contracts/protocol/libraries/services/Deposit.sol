// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {Types} from "../types/Types.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";

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
        Types.PoolConfig memory config = pools[poolId].config;
        
        // Validation block for operational controls
        require(!config.isPaused, "Deposit/pool-paused");
        require(config.depositsEnabled, "Deposit/deposits-disabled");
        require(assets >= config.minDepositAmount, "Deposit/amount-too-small");
        require(assets <= config.maxDepositAmount, "Deposit/amount-too-large");
        
        // Deposit cap check
        IERC7540Vault vault = IERC7540Vault(pools[poolId].vault);
        uint256 currentAssets = vault.totalAssets();
        require(currentAssets + assets <= config.depositCap, "Deposit/cap-exceeded");
        
        Types.Pool storage pool = pools[poolId];
        vault.requestDeposit(assets, controller, owner);
    }

    function fulfillDeposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.PoolConfig memory config = pools[poolId].config;
        
        // Validation block for operational controls
        require(!config.isPaused, "Deposit/pool-paused");
        require(config.depositsEnabled, "Deposit/deposits-disabled");
        
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.fulfillDepositRequest(assets, receiver);
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(vault.asset());
        uint256 aaveCollateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
        uint256 aaveBorrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
        
        // Set LTV ratio to 0 if no borrows
        pool.ltvRatio = aaveCollateralBalance == 0 ? 0 : aaveBorrowBalance.rayDiv(aaveCollateralBalance);
    }

    function deposit(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address owner
    ) internal {
        Types.PoolConfig memory config = pools[poolId].config;
        
        // Validation block for operational controls
        require(!config.isPaused, "Deposit/pool-paused");
        require(config.depositsEnabled, "Deposit/deposits-disabled");
        
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
        Types.PoolConfig memory config = pools[poolId].config;
        
        // Validation block for operational controls
        require(!config.isPaused, "Redeem/pool-paused");
        require(config.withdrawalsEnabled, "Redeem/withdrawals-disabled");
        
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
        Types.PoolConfig memory config = pools[poolId].config;
        
        // Validation block for operational controls
        require(!config.isPaused, "Redeem/pool-paused");
        require(config.withdrawalsEnabled, "Redeem/withdrawals-disabled");
        
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        uint256 shares = vault.convertToShares(assets);
        vault.fulfillRedeemRequest(shares, receiver);
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(vault.asset());
        uint256 aaveCollateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
        uint256 aaveBorrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
        pool.ltvRatio = aaveBorrowBalance.rayDiv(aaveCollateralBalance);
    }

    function redeem(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 assets,
        address receiver
    ) internal {
        Types.PoolConfig memory config = pools[poolId].config;
        
        // Validation block for operational controls
        require(!config.isPaused, "Redeem/pool-paused");
        require(config.withdrawalsEnabled, "Redeem/withdrawals-disabled");
        
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        vault.redeem(assets, msg.sender, receiver);
    }
}
