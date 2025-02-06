// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {IDToken} from "../../interfaces/IDToken.sol";
import {Types} from "../libraries/types/Types.sol";

contract DToken is IDToken, ERC20Upgradeable {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    address public underlyingAsset;

    /// @custom:oz-upgrades-unsafe-allow constructor
 	constructor() {
 	    _disableInitializers();
 	}

    function initialize(
        address _underlyingAsset,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __ERC20_init(_name, _symbol);
        require(_underlyingAsset != address(0), "DToken/invalid-asset-address");
        underlyingAsset = _underlyingAsset;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}