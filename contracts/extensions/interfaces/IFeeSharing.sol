// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IFeeSharing {
    function assign(uint256 _tokenId) external returns (uint256);
    function register(address _recipient) external returns (uint256);
}
