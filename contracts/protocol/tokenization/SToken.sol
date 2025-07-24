// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IPoolManager} from "../../interfaces/IPoolManager.sol";
import {ISToken} from "../../interfaces/ISToken.sol";
import {IERC7540Vault} from "../../interfaces/IERC7540.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Types} from "../libraries/types/Types.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";


contract SToken is ISToken, ERC20Upgradeable {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    address public poolManager;
    address public treasury;
    uint16 public poolId;

    // User distribution tracking
    mapping(address => uint256) public userDistributionBaselines;

    modifier onlyAuthorized() {
        require(
                _msgSender() == IPoolManager(poolManager).getPool(poolId).vault || 
                _msgSender() == poolManager, "SToken/only-authorized"
            );
        _;
    }

    // User index snapshots
    mapping(address => uint256) public userIndexes;

    /// @custom:oz-upgrades-unsafe-allow constructor
 	constructor() {
 	    _disableInitializers();
 	}

    function initialize(
        address _poolManager,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __ERC20_init(_name, _symbol);
        poolManager = _poolManager;
        treasury = _treasury;
        poolId = IPoolManager(_poolManager).getPoolCount();
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount
    ) external onlyAuthorized returns (bool) {
        Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
        userDistributionBaselines[onBehalfOf] = pool.cumulativeDistributionsPerShare;
        _mint(onBehalfOf, amount.toUint128());
        emit Transfer(address(0), onBehalfOf, amount);
        emit Mint(caller, onBehalfOf, amount);

        return (super.balanceOf(onBehalfOf) == 0);
  }

  function mintToTreasury(uint256 amount, uint256 index) external onlyAuthorized {
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled > 0, "SToken/invalid-mint-amount");
    _mint(treasury, amountScaled.toUint128());
    emit Transfer(address(0), treasury, amountScaled);
    emit Mint(msg.sender, treasury, amountScaled);
  }

  function burn(
    address from,
    address receiverOfUnderlying,
    uint256 amount
  ) external onlyAuthorized {
    // TODO: use cumulative distributions per share to calculate the amount to burn
    require(amount > 0, "SToken/invalid-burn-amount");
    require(super.balanceOf(from) >= amount, "SToken/insufficient-balance");
    Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
    IERC7540Vault vault = IERC7540Vault(pool.vault);

    userDistributionBaselines[from] = pool.cumulativeDistributionsPerShare;

    _burn(from, amount.toUint128());

    emit Transfer(from, address(0), amount);
    emit Burn(from, receiverOfUnderlying, amount);

    // Transfer underlying assets from vault to receiver
    
    IERC20(asset()).transferFrom(address(vault), receiverOfUnderlying, amount);
  }

  function totalClaimableReturns(address user) public view returns (uint256) {
        uint256 userShares = super.balanceOf(user);
        Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
        return userShares.rayMul(pool.cumulativeDistributionsPerShare - userDistributionBaselines[user]);
  }

  function getUserBaseline(address user) public view returns (uint256) {
    return userDistributionBaselines[user];
  }

//   function balanceOf(address user)
//     public
//     view
//     override (ERC20Upgradeable, IERC20)
//     returns (uint256) {
//         Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
//         IERC7540Vault vault = IERC7540Vault(pool.vault);
//         uint256 index = IPool(pool.aavePool).getReserveData(vault.asset()).liquidityIndex;
//         uint256 normalizedReturn = IPoolManager(poolManager).getNormalizedReturn(poolId);
//         return super.balanceOf(user).rayMul(index).rayMul(normalizedReturn);
//     }

    // function totalSupply()
    //     public
    //     view
    //     override (ERC20Upgradeable, IERC20)
    //     returns (uint256) {
    //         Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
    //         IERC7540Vault vault = IERC7540Vault(pool.vault);
    //         return super.totalSupply();
    //     }

    // function getReserveData() public view returns (Types.ReserveData memory) {
    //     Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
    //     IERC7540Vault vault = IERC7540Vault(pool.vault);
    //     return IPool(pool.aavePool).getReserveData(vault.asset());
    // }

    function asset() public view returns (address) {
        Types.Pool memory pool = IPoolManager(poolManager).getPool(poolId);
        IERC7540Vault vault = IERC7540Vault(pool.vault);
        return vault.asset();
    }
}
