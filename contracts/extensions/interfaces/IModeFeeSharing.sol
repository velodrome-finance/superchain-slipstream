// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IModeFeeSharing {
    /// @notice Address of the fee sharing contract.
    /// @return Fee sharing contract address
    function sfs() external view returns (address);

    /// @notice Token Id that sequencer fees are sent to.
    /// @return Token Id
    function tokenId() external view returns (uint256);
}
