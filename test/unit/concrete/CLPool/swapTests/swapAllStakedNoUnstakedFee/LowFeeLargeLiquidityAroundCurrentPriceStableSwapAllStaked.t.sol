pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLPoolSwapAllStakedNoUnstakeFeeTest, LeafCLGauge} from "./CLPoolSwapAllStakedNoUnstakeFee.t.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";
import {LiquidityAmounts} from "contracts/periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "contracts/core/libraries/TickMath.sol";

contract LowFeeLargeLiquidityAroundCurrentPriceStableSwapAllStakedTest is CLPoolSwapAllStakedNoUnstakeFeeTest {
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_10;

        uint160 startingPrice = encodePriceSqrt(1, 1);

        string memory poolName = ".low_fee_large_liquidity_around_current_price_stable_swap";
        address pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: startingPrice
        });

        uint128 liquidity = 2e18;

        stakedPositions.push(Position({tickLower: -tickSpacing, tickUpper: tickSpacing, liquidity: liquidity}));
        vm.startPrank(address(leafMessageModule));
        gauge = LeafCLGauge(
            leafVoter.createGauge({
                _poolFactory: address(poolFactory),
                _pool: address(pool),
                _votingRewardsFactory: address(votingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );
        vm.stopPrank();

        // set zero unstaked fee
        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(pool, 420);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            startingPrice,
            TickMath.getSqrtRatioAtTick(stakedPositions[0].tickLower),
            TickMath.getSqrtRatioAtTick(stakedPositions[0].tickUpper),
            liquidity
        );

        vm.startPrank(users.alice);
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
            amount0 + 1,
            amount1 + 1,
            stakedPositions[0].tickLower,
            stakedPositions[0].tickUpper,
            tickSpacing,
            users.alice
        );
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,) = ICLPool(pool).slot0();

        poolSetup = PoolSetup({
            poolName: poolName,
            pool: pool,
            gauge: address(gauge),
            poolBalance0: poolBalance0,
            poolBalance1: poolBalance1,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick
        });
    }
}
