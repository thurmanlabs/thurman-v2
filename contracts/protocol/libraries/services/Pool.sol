// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Types} from "../types/Types.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {IERC7540Vault} from "../../../interfaces/IERC7540.sol";
import {ISToken} from "../../../interfaces/ISToken.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {MathUtils} from "../math/MathUtils.sol";

library Pool {
    using WadRayMath for uint256;

    event PoolAdded(uint16 indexed poolId, address indexed vault, address indexed underlyingAsset);
    event MintedToTreasury(uint16 indexed poolId, uint256 amountMinted);
    event PoolConfigurationUpdated(uint16 indexed poolId);

    function addPool(
        mapping(uint16 => Types.Pool) storage pools,
        address vault,
        address originatorRegistry,
        uint256 marginFee,
        uint16 poolCount
    ) internal returns (bool) {
        pools[poolCount].vault = vault;
        pools[poolCount].originatorRegistry = originatorRegistry;
        pools[poolCount].config.marginFee = marginFee;
        
        // Initialize new operational control fields with default values
        pools[poolCount].config.depositsEnabled = false;
        pools[poolCount].config.withdrawalsEnabled = false;
        pools[poolCount].config.borrowingEnabled = false;
        pools[poolCount].config.isPaused = false;
        pools[poolCount].config.maxDepositAmount = type(uint256).max;
        pools[poolCount].config.minDepositAmount = 0;
        pools[poolCount].config.depositCap = type(uint256).max;
        
        IERC7540Vault _vault = IERC7540Vault(vault);
        emit PoolAdded(poolCount, vault, _vault.asset());
        return true;
    }

    /// @notice Sets the operational settings for a pool
    /// @param pools The mapping of pool IDs to pool data
    /// @param poolId The ID of the pool to update
    /// @param depositsEnabled Whether deposits are enabled
    /// @param withdrawalsEnabled Whether withdrawals are enabled
    /// @param borrowingEnabled Whether borrowing is enabled
    /// @param isPaused Whether the pool is paused
    function setPoolOperationalSettings(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        bool depositsEnabled,
        bool withdrawalsEnabled,
        bool borrowingEnabled,
        bool isPaused,
        uint256 maxDepositAmount,
        uint256 minDepositAmount,
        uint256 depositCap
    ) internal {
        pools[poolId].config.depositsEnabled = depositsEnabled;
        pools[poolId].config.withdrawalsEnabled = withdrawalsEnabled;
        pools[poolId].config.borrowingEnabled = borrowingEnabled;
        pools[poolId].config.isPaused = isPaused;
        pools[poolId].config.maxDepositAmount = maxDepositAmount;
        pools[poolId].config.minDepositAmount = minDepositAmount;
        pools[poolId].config.depositCap = depositCap;

        emit PoolConfigurationUpdated(poolId);
    }

    /// @notice Updates the pool's cumulative distributions per share and last distribution timestamp
    /// @param pools The mapping of pool IDs to pool data
    /// @param poolId The ID of the pool to update
    /// @param paymentAmount The amount of payment to be distributed to LPs
    function update(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 paymentAmount
    ) internal {
        Types.Pool storage pool = pools[poolId];
        ISToken sToken = ISToken(IERC7540Vault(pool.vault).getShare());
        uint256 currentTotalShares = sToken.totalSupply();
        require(currentTotalShares > 0, "Pool/invalid-total-shares");

        pool.cumulativeDistributionsPerShare += paymentAmount.rayDiv(currentTotalShares);
        pool.lastDistributionTimestamp = uint40(block.timestamp);
    }

    function transferSaleProceeds(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        address originator,
        uint256 amount
    ) internal {
        Types.Pool storage pool = pools[poolId];
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        IOriginatorRegistry originatorRegistry = IOriginatorRegistry(pool.originatorRegistry);
        Validation.validateTransferSaleProceeds(pool, originator, amount);
        originatorRegistry.transferSaleProceeds(poolId, originator, amount);
        vault.transferSaleProceeds(amount, originator);
    }

    // function getNormalizedReturn(Types.Pool memory pool) internal view returns (uint256) {
    //     uint40 timestamp = pool.lastUpdateTimestamp;
    //     uint256 utilizationRate = getUtilizationRate(pool);

    //     if (timestamp == block.timestamp) {
    //         return pool.liquidityPremiumIndex;
    //     }

    //     return (MathUtils.calculateLinearInterest(
    //         pool.config.liquidityPremiumRate, 
    //         pool.lastUpdateTimestamp
    //     ).rayMul(utilizationRate) + WadRayMath.RAY).rayMul(pool.liquidityPremiumIndex);
    // }

    // function getUtilizationRate(Types.Pool memory pool) internal view returns (uint256) {
    //     IERC7540Vault vault = IERC7540Vault(pool.vault);
    //     Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(vault.asset());
    //     uint256 collateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
    //     uint256 borrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
    //     return borrowBalance.rayDiv(collateralBalance);
    // }

    function mintToTreasury(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 amount
    ) internal {
        Types.Pool memory pool = getPool(pools, poolId);
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        uint256 index = IPool(pool.aavePool).getReserveData(vault.asset()).liquidityIndex;
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled > 0, "Pool/invalid-mint-amount");
        
        if (pool.accruedToTreasury != 0) {
            pool.accruedToTreasury = 0;
            address sToken = IERC7540Vault(pool.vault).getShare();
            ISToken(sToken).mintToTreasury(pool.accruedToTreasury, index);   
            
            emit MintedToTreasury(poolId, pool.accruedToTreasury);
        }
    }

    function getPool(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId
    ) internal view returns (Types.Pool memory) {
        return pools[poolId];
    }
}