// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "../NonfungiblePositionManager.sol";
import "../../core/interfaces/ICLFactory.sol";

contract MockTimeNonfungiblePositionManager is NonfungiblePositionManager {
    uint256 time;

    constructor(address _owner, address _factory, address _WETH9, address _tokenDescriptor)
        NonfungiblePositionManager(_owner, _factory, _WETH9, _tokenDescriptor, "Slipstream Position NFT v1", "CL-POS")
    {}

    function createPoolFromFactory(address tokenA, address tokenB, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool)
    {
        pool = ICLFactory(factory).getPool(tokenA, tokenB, tickSpacing);
        if (pool == address(0)) {
            pool = ICLFactory(factory).createPool(tokenA, tokenB, tickSpacing, sqrtPriceX96);
        }
    }

    function _blockTimestamp() internal view override returns (uint256) {
        return time;
    }

    function setTime(uint256 _time) external {
        time = _time;
    }
}
