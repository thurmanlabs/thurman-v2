// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IPoolManager} from "../../interfaces/IPoolManager.sol";
import {ISToken} from "../../interfaces/ISToken.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Types} from "../libraries/types/Types.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";


contract SToken is ISToken, ERC20Upgradeable {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    address public underlyingAsset;
    address public aavePool;
    address public vault;
    address public poolManager;
    address public treasury;
    uint16 public poolId;
    
    modifier onlyAuthorized() {
        require(_msgSender() == vault || _msgSender() == poolManager, "SToken/only-authorized");
        _;
    }

    // User index snapshots
    mapping(address => uint256) public userIndexes;

    /// @custom:oz-upgrades-unsafe-allow constructor
 	constructor() {
 	    _disableInitializers();
 	}

    function initialize(
        address _underlyingAsset,
        address _aavePool,
        address _poolManager,
        address _treasury,
        uint16 _poolId,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __ERC20_init(_name, _symbol);
        require(_aavePool != address(0), "SToken/invalid-pool-address");
        require(_underlyingAsset != address(0), "SToken/invalid-asset-address");
        underlyingAsset = _underlyingAsset;
        aavePool = _aavePool;
        poolManager = _poolManager;
        treasury = _treasury;
        poolId = _poolId;
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyAuthorized returns (bool) {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled > 0, "SToken/invalid-mint-amount");
        uint256 scaledBalance = super.balanceOf(onBehalfOf);
        uint256 balanceIncrease = scaledBalance.rayMul(index) - 
            scaledBalance.rayMul(userIndexes[onBehalfOf]);
        userIndexes[onBehalfOf] = index;
        _mint(onBehalfOf, amountScaled.toUint128());
        uint256 amountToMint = amountScaled + balanceIncrease;
        emit Transfer(address(0), onBehalfOf, amountToMint);
        emit Mint(caller, onBehalfOf, amountToMint, balanceIncrease, index);

        return (scaledBalance == 0);
  }

  function mintToTreasury(uint256 amount, uint256 index) external onlyAuthorized {
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled > 0, "SToken/invalid-mint-amount");
    _mint(treasury, amountScaled.toUint128());
    emit Transfer(address(0), treasury, amountScaled);
    emit Mint(msg.sender, treasury, amountScaled, amountScaled, index);
  }

  function burn(
    address from,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) external onlyAuthorized {
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled > 0, "SToken/invalid-burn-amount");
    uint256 scaledBalance = super.balanceOf(from);
    uint256 balanceIncrease = scaledBalance.rayMul(index) - 
        scaledBalance.rayMul(userIndexes[from]);
    userIndexes[from] = index;
    _burn(from, amountScaled.toUint128());

    if (balanceIncrease > amount) {
        uint256 amountToMint = balanceIncrease - amount;
        emit Transfer(address(0), from, amountToMint);
        emit Mint(from, from, amountToMint, balanceIncrease, index);
    } else {
        uint256 amountToBurn = amount - balanceIncrease;
        emit Transfer(from, address(0), amountToBurn);
        emit Burn(from, receiverOfUnderlying, amountToBurn, balanceIncrease, index);
    }
  }

  function balanceOf(address user)
    public
    view
    override (ERC20Upgradeable, IERC20)
    returns (uint256) {
        uint256 index = IPool(aavePool).getReserveData(underlyingAsset).liquidityIndex;
        uint256 normalizedReturn = IPoolManager(poolManager).getNormalizedReturn(poolId);
        return super.balanceOf(user).rayMul(index).rayMul(normalizedReturn);
    }

    function totalSupply()
        public
        view
        override (ERC20Upgradeable, IERC20)
        returns (uint256) {
            return super.totalSupply().rayMul(IPool(aavePool).getReserveData(underlyingAsset).liquidityIndex);
        }

    function getReserveData() public view returns (Types.ReserveData memory) {
        return IPool(aavePool).getReserveData(underlyingAsset);
    }

    function setVault(uint16 _poolId) external onlyAuthorized {
        Types.Pool memory pool = IPoolManager(poolManager).getPool(_poolId);
        vault = pool.vault;
    }
}
