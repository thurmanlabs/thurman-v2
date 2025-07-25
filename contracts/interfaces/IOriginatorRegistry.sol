// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Types} from "../protocol/libraries/types/Types.sol";

interface IOriginatorRegistry {
    event OriginatorInterestAccrued(address indexed originator, uint256 amount, uint16 indexed poolId, uint256 indexed loanId);
    event OriginatorWithdrawal(address indexed originator, uint256 amount);
    event OriginatorRegistered(address indexed originator, address indexed registrar);
    event SaleProceedsTransferred(uint16 indexed poolId, address indexed originator, uint256 amount);
    
    function accrueInterest(address originator, uint256 amount, uint16 poolId, uint256 loanId) external;
    function recordOriginatedPrincipal(address originator, uint256 amount, uint16 poolId) external;
    function withdraw() external;
    function registerOriginator(address originator) external;
    function getOriginatorBalance(address originator) external view returns (uint256);
    function isRegistered(address originator) external view returns (bool);
    function transferSaleProceeds(uint16 poolId, address originator, uint256 amount) external;
}