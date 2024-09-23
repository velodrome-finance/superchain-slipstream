pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest, ICLPool, CLLeafGauge} from "./CLFactory.t.sol";

contract CreatePoolTest is CLFactoryTest {
    function test_RevertIf_SameTokens() public {
        vm.expectRevert();
        poolFactory.createPool({
            tokenA: TEST_TOKEN_0,
            tokenB: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.createPool({
            tokenA: TEST_TOKEN_0,
            tokenB: address(0),
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.expectRevert();
        poolFactory.createPool({
            tokenA: address(0),
            tokenB: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.expectRevert();
        poolFactory.createPool({
            tokenA: address(0),
            tokenB: address(0),
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }

    function test_RevertIf_TickSpacingNotEnabled() public {
        vm.expectRevert();
        poolFactory.createPool({
            tokenA: TEST_TOKEN_0,
            tokenB: TEST_TOKEN_1,
            tickSpacing: 250,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }

    function test_CreatePoolWithReversedTokens() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_1,
            token1: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }

    function test_CreatePoolWithTickSpacingStable() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_STABLE,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        assertEqUint(poolFactory.getSwapFee(pool), 100);
    }

    function test_CreatePoolWithTickSpacingLow() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        assertEqUint(poolFactory.getSwapFee(pool), 500);
    }

    function test_CreatePoolWithTickSpacingMedium() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_MEDIUM,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        assertEqUint(poolFactory.getSwapFee(pool), 500);

        CLLeafGauge gauge =
            CLLeafGauge(leafVoter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));
        address feesVotingReward = leafVoter.gaugeToFees(address(gauge));

        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(xVelo));
        assertTrue(gauge.isPool());
    }

    function test_CreatePoolWithTickSpacingHigh() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_HIGH,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        assertEqUint(poolFactory.getSwapFee(pool), 3_000);

        CLLeafGauge gauge =
            CLLeafGauge(leafVoter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));
        address feesVotingReward = leafVoter.gaugeToFees(address(gauge));

        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(xVelo));
        assertTrue(gauge.isPool());
    }

    function test_CreatePoolWithTickSpacingVolatile() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_VOLATILE,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        assertEqUint(poolFactory.getSwapFee(pool), 10_000);

        CLLeafGauge gauge =
            CLLeafGauge(leafVoter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));
        address feesVotingReward = leafVoter.gaugeToFees(address(gauge));

        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(xVelo));
        assertTrue(gauge.isPool());
    }
}
