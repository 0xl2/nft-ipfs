// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

interface Ideployer {

  function  deployerWrappedAsset(string calldata _name , string calldata _symbol, uint256 lossless) external returns (address);
  
}