// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Types} from "../types/Types.sol";

library Pool {
    function addPool(
        mapping(uint16 => Types.Pool) storage pools,
        address vault,
        uint16 poolCount
    ) internal returns (bool) {
        pools[poolCount].vault = vault;
        return true;
    }
}