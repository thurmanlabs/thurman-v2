// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {IDToken} from "../../interfaces/IDToken.sol";
import {IPoolManager} from "../../interfaces/IPoolManager.sol";
import {Types} from "../libraries/types/Types.sol";

contract DToken is IDToken, ERC20Upgradeable {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    address public poolManager;
    uint16 public poolId;

    /// @custom:oz-upgrades-unsafe-allow constructor
 	constructor() {
 	    _disableInitializers();
 	}

    modifier onlyAuthorized() {
        require(
                _msgSender() == IPoolManager(poolManager).getPool(poolId).vault || 
                _msgSender() == poolManager, "DToken/only-authorized"
            );
        _;
    }

    function initialize(
        address _poolManager,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __ERC20_init(_name, _symbol);
        require(_poolManager != address(0), "DToken/invalid-pool-manager-address");
        poolManager = _poolManager;
        poolId = IPoolManager(_poolManager).getPoolCount();
    }

    function mint(address to, uint256 amount) external onlyAuthorized {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyAuthorized {
        _burn(from, amount);
    }
}