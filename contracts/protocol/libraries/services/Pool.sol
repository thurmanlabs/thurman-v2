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
        address sToken,
        uint256 collateralCushion,
        uint256 ltvRatioCap,
        uint256 baseRate,
        uint256 liquidityPremiumRate,
        uint256 marginFee,
        uint16 poolCount
    ) internal returns (bool) {
        pools[poolCount].vault = vault;
        pools[poolCount].aavePool = aavePool;
        pools[poolCount].underlyingAsset = underlyingAsset;
        pools[poolCount].sToken = sToken;
        pools[poolCount].config.collateralCushion = collateralCushion;
        pools[poolCount].config.ltvRatioCap = ltvRatioCap;
        pools[poolCount].config.baseRate = baseRate;
        pools[poolCount].config.liquidityPremiumRate = liquidityPremiumRate;
        pools[poolCount].config.marginFee = marginFee;
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

        return MathUtils.calculateLinearInterest(
            pool.config.liquidityPremiumRate, 
            pool.lastUpdateTimestamp
        ).rayMul(utilizationRate).rayMul(pool.liquidityPremiumIndex);
    }

    function getUtilizationRate(Types.Pool memory pool) internal view returns (uint256) {
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(pool.underlyingAsset);
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
        Types.ReserveData memory reserveData = IPool(pool.aavePool).getReserveData(pool.underlyingAsset);
        IAToken aToken = IAToken(reserveData.aTokenAddress);
        uint256 aaveCollateralBalance = aToken.balanceOf(pool.vault);
        uint256 aaveBorrowBalance = IVariableDebtToken(reserveData.variableDebtTokenAddress).balanceOf(pool.vault);
        pool.ltvRatio = aaveBorrowBalance.rayDiv(aaveCollateralBalance);
        return pool;
    }
}