// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOriginatorRegistry} from "../../interfaces/IOriginatorRegistry.sol";
import {Types} from "../libraries/types/Types.sol";

contract OriginatorRegistry is 
    Initializable, 
    AccessControlUpgradeable, 
    IOriginatorRegistry 
{
    bytes32 public constant ACCRUER_ROLE = keccak256("ACCRUER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Storage variables directly in the contract
    address public paymentAsset;
    mapping(address => uint256) public originatorBalances;
    mapping(address => bool) public isRegisteredOriginator;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address admin, address _paymentAsset) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        paymentAsset = _paymentAsset;
    }
    
    function accrueInterest(
        address originator, 
        uint256 amount, 
        uint16 poolId, 
        uint256 loanId
    ) external onlyRole(ACCRUER_ROLE) {
        originatorBalances[originator] += amount;
        
        emit OriginatorInterestAccrued(originator, amount, poolId, loanId);
    }
    
    function withdraw() external {
        uint256 amount = originatorBalances[msg.sender];
        require(amount > 0, "OriginatorRegistry/no-balance");
        
        originatorBalances[msg.sender] = 0;
        IERC20(paymentAsset).transfer(msg.sender, amount);
        
        emit OriginatorWithdrawal(msg.sender, amount);
    }
    
    function registerOriginator(address originator) external onlyRole(ADMIN_ROLE) {
        isRegisteredOriginator[originator] = true;
        emit OriginatorRegistered(originator, msg.sender);
    }
    
    function getOriginatorBalance(address originator) external view returns (uint256) {
        return originatorBalances[originator];
    }
    
    function grantAccruerRole(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(ACCRUER_ROLE, account);
    }
    
    function revokeAccruerRole(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(ACCRUER_ROLE, account);
    }
}