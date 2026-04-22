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

    function test_InitialState() external {
        assertEq(address(gauge.pool()), address(pool));
        assertEq(address(gauge.gaugeFactory()), address(leafGaugeFactory));
        assertEq(address(gauge.voter()), address(leafVoter));
        assertEq(address(gauge.nft()), address(nft));
        assertEq(gauge.rewardToken(), address(leafXVelo));
        assertEq(gauge.token0(), address(token0));
        assertEq(gauge.token1(), address(token1));
        assertEq(gauge.tickSpacing(), TICK_SPACING_60);
        assertNotEq(gauge.feesVotingReward(), address(0));
        assertTrue(gauge.isPool());

        assertEq(gauge.periodFinish(), 0);
        assertEq(gauge.rewardRate(), 0);
        assertEq(gauge.fees0(), 0);
        assertEq(gauge.fees1(), 0);

        assertEq(leafGaugeFactory.penaltyRate(), 0);
        assertEq(leafGaugeFactory.defaultMinStakeTime(), 0);
    }
}
