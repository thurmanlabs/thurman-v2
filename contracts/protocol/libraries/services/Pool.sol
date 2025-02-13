// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Types} from "../types/Types.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {ISToken} from "../../../interfaces/ISToken.sol";
import {MathUtils} from "../math/MathUtils.sol";

library Pool {
    using WadRayMath for uint256;

    event PoolAdded(uint16 indexed poolId, address indexed vault, address indexed underlyingAsset);
    event MintedToTreasury(uint16 indexed poolId, uint256 amountMinted);

    function addPool(
        mapping(uint16 => Types.Pool) storage pools,
        address vault,
        address aavePool,
        address underlyingAsset,
        address aToken,
        address variableDebtToken,
        address sToken,
        uint256 collateralCushion,
        uint256 ltvRatioCap,
        uint256 baseRate,
        uint16 poolCount
    ) internal returns (bool) {
        pools[poolCount].vault = vault;
        pools[poolCount].aavePool = aavePool;
        pools[poolCount].underlyingAsset = underlyingAsset;
        pools[poolCount].aToken = aToken;
        pools[poolCount].variableDebtToken = variableDebtToken;
        pools[poolCount].sToken = sToken;
        pools[poolCount].collateralCushion = collateralCushion;
        pools[poolCount].ltvRatioCap = ltvRatioCap;
        pools[poolCount].baseRate = baseRate;
        pools[poolCount].liquidityPremiumIndex = WadRayMath.RAY;
        pools[poolCount].lastUpdateTimestamp = uint40(block.timestamp);

        emit PoolAdded(poolCount, vault, underlyingAsset);
        return true;
    }

    function update(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId
    ) internal {
        Types.Pool storage pool = pools[poolId];
        uint256 utilizationRate = getUtilizationRate(pool);
        uint256 currentIndex = pool.liquidityPremiumIndex;
        if (pool.liquidityPremiumRate != 0) {
            uint256 cumulatedInterest = MathUtils.calculateLinearInterest(
                pool.liquidityPremiumRate, 
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

        return MathUtils.calculateLinearInterest(
            pool.liquidityPremiumRate, 
            pool.lastUpdateTimestamp
        ).rayMul(utilizationRate).rayMul(pool.liquidityPremiumIndex);
    }

    function getUtilizationRate(Types.Pool memory pool) internal view returns (uint256) {
        uint256 collateralBalance = IAToken(pool.aToken).balanceOf(pool.vault);
        uint256 borrowBalance = IVariableDebtToken(pool.variableDebtToken).balanceOf(pool.vault);
        return borrowBalance.rayDiv(collateralBalance);
    }

    function mintToTreasury(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId,
        uint256 amount
    ) internal {
        Types.Pool memory pool = getPool(pools, poolId);
        uint256 index = IPool(pool.aavePool).getReserveData(pool.underlyingAsset).liquidityIndex;
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled > 0, "Pool/invalid-mint-amount");
        
        if (pool.accruedToTreasury != 0) {
            pool.accruedToTreasury = 0;
            ISToken(pool.sToken).mintToTreasury(pool.accruedToTreasury, index);   
            
            emit MintedToTreasury(poolId, pool.accruedToTreasury);
        }
    }

    function getPool(
        mapping(uint16 => Types.Pool) storage pools,
        uint16 poolId
    ) internal view returns (Types.Pool memory) {
        Types.Pool memory pool = pools[poolId];
        IAToken aToken = IAToken(pool.aToken);
        pool.aaveCollateralBalance = aToken.balanceOf(pool.vault);
        pool.aaveBorrowBalance = IVariableDebtToken(pool.variableDebtToken).balanceOf(pool.vault);
        pool.ltvRatio = pool.aaveBorrowBalance.rayDiv(pool.aaveCollateralBalance);
        return pool;
    }
}