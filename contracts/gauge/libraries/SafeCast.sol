// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
    /// @notice Cast a uint128 to an int128, revert on overflow
    /// @param y The uint128 to be cast
    /// @return z The cast integer, now type int128
    function toInt128(uint128 y) internal pure returns (int128 z) {
        require(y < 2 ** 127);
        z = int128(y);
    }
    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint160

    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }
}
