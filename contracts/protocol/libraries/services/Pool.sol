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

    function addPool(
        mapping(uint16 => Types.Pool) storage pools,
        address vault,
        address aavePool,
        address originatorRegistry,
        uint256 collateralCushion,
        uint256 ltvRatioCap,
        uint256 liquidityPremiumRate,
        uint256 marginFee,
        uint16 poolCount
    ) internal returns (bool) {
        pools[poolCount].vault = vault;
        pools[poolCount].aavePool = aavePool;
        pools[poolCount].originatorRegistry = originatorRegistry;
        pools[poolCount].config.collateralCushion = collateralCushion;
        pools[poolCount].config.ltvRatioCap = ltvRatioCap;
        pools[poolCount].config.liquidityPremiumRate = liquidityPremiumRate;
        pools[poolCount].config.marginFee = marginFee;
        
        // Initialize new operational control fields with default values
        pools[poolCount].config.depositsEnabled = false;
        pools[poolCount].config.withdrawalsEnabled = false;
        pools[poolCount].config.borrowingEnabled = false;
        pools[poolCount].config.isPaused = false;
        pools[poolCount].config.maxDepositAmount = type(uint256).max;
        pools[poolCount].config.minDepositAmount = 0;
        pools[poolCount].config.depositCap = type(uint256).max;
        
        pools[poolCount].liquidityPremiumIndex = WadRayMath.RAY;
        pools[poolCount].lastUpdateTimestamp = uint40(block.timestamp);

        IERC7540Vault _vault = IERC7540Vault(vault);
        emit PoolAdded(poolCount, vault, _vault.asset());
        return true;
    }

    function update(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId
    ) internal {
        Types.Pool storage pool = pools[poolId];
        uint256 utilizationRate = getUtilizationRate(pool);
        uint256 currentIndex = pool.liquidityPremiumIndex;
        if (pool.config.liquidityPremiumRate != 0) {
            uint256 cumulatedInterest = MathUtils.calculateLinearInterest(
                pool.config.liquidityPremiumRate, 
                pool.lastUpdateTimestamp
            );
            pool.liquidityPremiumIndex = currentIndex.rayMul(cumulatedInterest.rayMul(utilizationRate));
        }
        pool.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function getNormalizedReturn(Types.Pool memory pool) internal view returns (uint256) {
        uint40 timestamp = pool.lastUpdateTimestamp;
        uint256 utilizationRate = getUtilizationRate(pool);

        if (timestamp == block.timestamp) {
            return pool.liquidityPremiumIndex;
        }

        return (MathUtils.calculateLinearInterest(
            pool.config.liquidityPremiumRate, 
            pool.lastUpdateTimestamp
        ).rayMul(utilizationRate) + WadRayMath.RAY).rayMul(pool.liquidityPremiumIndex);
    }

    function getUtilizationRate(Types.Pool memory pool) internal view returns (uint256) {
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(vault.asset());
        uint256 collateralBalance = IAToken(reserveData.aTokenAddress).balanceOf(pool.vault);
        uint256 borrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
        return borrowBalance.rayDiv(collateralBalance);
    }

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