// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

abstract contract Constants {
    /// @dev Entropy used for deterministic deployments across chains
    /// @dev Only use values from 0x..40 to 0x..49 to avoid collisions
    bytes11 public constant CL_POOL_ENTROPY = 0x0000000000000000000041;
    bytes11 public constant CL_POOL_FACTORY_ENTROPY = 0x0000000000000000000042;
    bytes11 public constant NFT_POSITION_DESCRIPTOR = 0x0000000000000000000043;
    bytes11 public constant NFT_POSITION_MANAGER = 0x0000000000000000000044;
    bytes11 public constant CL_GAUGE_ENTROPY = 0x0000000000000000000045;
    bytes11 public constant CL_GAUGE_FACTORY_ENTROPY = 0x0000000000000000000046;
    bytes11 public constant MIXED_QUOTER_ENTROPY = 0x0000000000000000000047;
    bytes11 public constant QUOTER_ENTROPY = 0x0000000000000000000048;
    bytes11 public constant SWAP_ROUTER_ENTROPY = 0x0000000000000000000049;
}
