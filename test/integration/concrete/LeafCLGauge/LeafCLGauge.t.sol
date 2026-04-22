pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseForkFixture.sol";
import {Position} from "contracts/core/libraries/Position.sol";

contract LeafCLGaugeTest is BaseForkFixture {
    CLPool public pool;
    LeafCLGauge public gauge;

    function setUp() public virtual override {
        super.setUp();

        pool = CLPool(
            leafPoolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        vm.prank(address(leafMessageModule));
        gauge = LeafCLGauge(
            leafVoter.createGauge({
                _poolFactory: address(leafPoolFactory),
                _pool: address(pool),
                _votingRewardsFactory: address(votingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );
    }
}
