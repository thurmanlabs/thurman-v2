// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Deposit} from "../libraries/services/Deposit.sol";
import {PoolManagerStorage} from "./PoolManagerStorage.sol";
import {IPoolManager} from "../../interfaces/IPoolManager.sol";

contract PoolManager is Initializable, OwnableUpgradeable, PoolManagerStorage, IPoolManager {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() external virtual initializer {
        __Ownable_init(msg.sender);
    }

    function deposit(uint16 poolId, uint256 assets, address receiver) external {
        Deposit.deposit(_pools, poolId, assets, receiver);
    }

    function fulfillDeposit(uint16 poolId, uint256 assets, uint256 shares, address receiver) external {
        Deposit.fulfillDeposit(_pools, poolId, assets, shares, receiver); 
    }

    function redeem(uint16 poolId, uint256 shares, address receiver) external {
        Deposit.redeem(_pools, poolId, shares, receiver);
    }

    function requestRedeem(uint16 poolId, uint256 shares, address controller, address owner) external {
        Deposit.requestRedeem(_pools, poolId, shares, controller, owner);
    }

    function fulfillRedeem(uint16 poolId, uint256 shares, uint256 assets, address receiver) external {
        Deposit.fulfillRedeem(_pools, poolId, shares, assets, receiver);
    }

    function requestDeposit(uint16 poolId, uint256 assets) external {
        Deposit.requestDeposit(_pools, poolId, assets, msg.sender, msg.sender);
    }
}
