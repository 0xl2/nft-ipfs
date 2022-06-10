// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;


interface IbridgePool {

     function validPool(address poolAddress) external view returns (bool);
     function topUp(address poolAddress, uint256 amount) external payable;
     function sendOut(address poolAddress , address receiver , uint256 amount) external;
     function createPool(address poolAddress, uint256 debtThreshold) external;
    
}