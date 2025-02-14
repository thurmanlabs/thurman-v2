// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Deposit} from "../libraries/services/Deposit.sol";
import {PoolManagerStorage} from "./PoolManagerStorage.sol";
import {IPoolManager} from "../../interfaces/IPoolManager.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {ISToken} from "../../interfaces/ISToken.sol";
import {Pool} from "../libraries/services/Pool.sol";
import {Loan} from "../libraries/services/Loan.sol";
import {Types} from "../libraries/types/Types.sol";

contract PoolManager is Initializable, OwnableUpgradeable, PoolManagerStorage, IPoolManager {
    using Pool for Types.Pool;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() external virtual initializer {
        __Ownable_init(msg.sender);
        _poolCount = 0;
    }

    function addPool(
        address vault,
        address aavePool,
        uint256 collateralCushion,
        uint256 ltvRatioCap,
        uint256 baseRate,
        uint256 liquidityPremiumRate,
        uint256 marginFee
    ) external onlyOwner {
        if (Pool.addPool(
                _pools, 
                vault, 
                aavePool, 
                collateralCushion, 
                ltvRatioCap, 
                baseRate,
                liquidityPremiumRate,
                marginFee,
                _poolCount
            )) {
            _poolCount++;
        }
    }

    function deposit(uint16 poolId, uint256 assets, address receiver) external {
        Deposit.deposit(_pools, poolId, assets, receiver);
    }

    function fulfillDeposit(uint16 poolId, uint256 assets, address receiver) external onlyOwner {
        Deposit.fulfillDeposit(_pools, poolId, assets, receiver);
    }

    function redeem(uint16 poolId, uint256 assets, address receiver) external {
        Deposit.redeem(_pools, poolId, assets, receiver);
    }

    function requestRedeem(uint16 poolId, uint256 assets, address controller, address owner) external {
        Deposit.requestRedeem(_pools, poolId, assets, controller, owner);
    }

    function fulfillRedeem(uint16 poolId, uint256 assets, address receiver) external onlyOwner {
        Deposit.fulfillRedeem(_pools, poolId, assets, receiver);
    }

    function requestDeposit(uint16 poolId, uint256 assets) external {
        Deposit.requestDeposit(_pools, poolId, assets, msg.sender, msg.sender);
    }

    function initLoan(
        uint16 poolId,
        address borrower,
        uint256 principal,
        uint16 termMonths,
        uint256 interestRate
    ) external onlyOwner {
        Loan.initLoan(_pools, poolId, borrower, principal, termMonths, interestRate);
    }

    function repayLoan(
        uint16 poolId,
        uint256 assets,
        address onBehalfOf,
        uint256 loanId
    ) external {
        Loan.repayLoan(_pools, poolId, assets, onBehalfOf, loanId);
    }

    function guarantee(
        uint16 poolId,
        uint256 assets
    ) external {
        Deposit.guarantee(_pools, poolId, assets);
    }
    
    function mintToTreasury(uint16 poolId, uint256 amount) external {
        Pool.mintToTreasury(_pools, poolId, amount);
    }

    function getPool(uint16 poolId) external view returns (Types.Pool memory) {
        return Pool.getPool(_pools, poolId);
    }

    function getPoolCount() external view returns (uint16) {
        return _poolCount;
    }

    function getNormalizedReturn(uint16 poolId) external view returns (uint256) {
        return _pools[poolId].getNormalizedReturn();
    }

    function isOwner(address _address) external view returns (bool) {
        return _address == owner();
    }

}
