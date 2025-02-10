// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Types} from "../types/Types.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {WadRayMath} from "../math/WadRayMath.sol";

library Pool {
    using WadRayMath for uint256;

    function addPool(
        mapping(uint16 => Types.Pool) storage pools,
        address vault,   
        uint256 collateralCushion,
        uint256 ltvRatioCap,
        uint16 poolCount
    ) internal returns (bool) {
        pools[poolCount].vault = vault;
        pools[poolCount].collateralCushion = collateralCushion;
        pools[poolCount].ltvRatioCap = ltvRatioCap;
        return true;
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