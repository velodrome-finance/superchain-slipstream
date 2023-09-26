pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGauge.t.sol";

contract LiquidityManagementBase is CLGaugeTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );

        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);
        token0.approve(address(gauge), type(uint256).max);
        token1.approve(address(gauge), type(uint256).max);

        vm.label({account: address(gauge), newLabel: "Gauge"});
        vm.label({account: address(pool), newLabel: "Pool"});
    }
}