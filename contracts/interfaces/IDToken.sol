// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDToken is IERC20 {
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    /**
     * @notice Mints `amount` dTokens to `to`
     * @param to The address of the user to mint to
     * @param amount The amount of dTokens to mint
     */
    function mint(address to, uint256 amount) external;
    
    /**
     * @notice Burns `amount` dTokens from `from`
     * @param from The address of the user to burn from
     * @param amount The amount of dTokens to burn
     */
    function burn(address from, uint256 amount) external;
}
