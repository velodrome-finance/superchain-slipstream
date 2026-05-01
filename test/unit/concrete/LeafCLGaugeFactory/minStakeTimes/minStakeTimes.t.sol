pragma solidity ^0.7.6;
pragma abicoder v2;

import "../LeafCLGaugeFactory.t.sol";

contract MinStakeTimesConcreteUnitTest is LeafCLGaugeFactoryTest {
    address public pool;

    function setUp() public override {
        super.setUp();
        pool = leafPoolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: TICK_SPACING_60,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }

    function test_WhenNoPerPoolOverrideIsSet() external {
        // It should return the default min stake time
        vm.prank(users.owner);
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: 300});

        assertEq(leafGaugeFactory.minStakeTimes(pool), 300);
    }

    function test_WhenAPerPoolOverrideIsSet() external {
        // It should return the per-pool min stake time
        vm.startPrank(users.owner);
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: 300});
        leafGaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 600});
        vm.stopPrank();

        assertEq(leafGaugeFactory.minStakeTimes(pool), 600);
    }
}
