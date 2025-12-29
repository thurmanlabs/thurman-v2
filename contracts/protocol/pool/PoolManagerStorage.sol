// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {Types} from "../libraries/types/Types.sol";

contract PoolManagerStorage {
    mapping(uint16 => Types.Pool) public _pools;
    uint16 public _poolCount;

    // Reserve storage slots for future upgrades
    uint256[48] private __gap;
}