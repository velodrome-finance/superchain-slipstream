pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest, ICLPool, LeafCLGauge} from "./CLFactory.t.sol";

contract GetUnstakedFeeTest is CLFactoryTest {
    LeafCLGauge public gauge;

    function test_KilledGaugeReturnsZeroUnstakedFee() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            _token0: TEST_TOKEN_1,
            _token1: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        vm.startPrank(address(leafMessageModule));
        gauge = LeafCLGauge(
            leafVoter.createGauge({
                _poolFactory: address(poolFactory),
                _pool: address(pool),
                _votingRewardsFactory: address(votingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );

        assertEq(leafVoter.isAlive(address(gauge)), true);
        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 100_000);

        leafVoter.killGauge(address(gauge));

        assertEq(leafVoter.isAlive(address(gauge)), false);
        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 0);
    }

    function test_NoGaugeReturnsZeroUnstakedFee() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            _token0: TEST_TOKEN_1,
            _token1: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 0);
    }
}
