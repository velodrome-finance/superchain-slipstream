pragma solidity ^0.7.6;
pragma abicoder v2;

import {
    CLPoolSwapPartiallyStakedWithUnstakeFeeTest, LeafCLGauge
} from "./CLPoolSwapPartiallyStakedWithUnstakeFee.t.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";
import {LiquidityAmounts} from "contracts/periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "contracts/core/libraries/TickMath.sol";

contract MediumFeeCloseToMinPricePartiallyStakedWithUnstakedFeeTest is CLPoolSwapPartiallyStakedWithUnstakeFeeTest {
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        // hardcoded value because the calculated value with the
        // util function returns an incorrect result
        // sqrt(1 / 2^127) * 2^96
        uint160 startingPrice = 6085630636;

        string memory poolName = ".close_to_min_price";
        address pool = leafPoolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: startingPrice
        });

        uint128 liquidity = 2e18;

        stakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );
        vm.startPrank(address(leafMessageModule));
        gauge = LeafCLGauge(
            leafVoter.createGauge({
                _poolFactory: address(leafPoolFactory),
                _pool: address(pool),
                _votingRewardsFactory: address(votingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );

        vm.stopPrank();

        // set zero unstaked fee
        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(pool, 125_000);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            startingPrice,
            TickMath.getSqrtRatioAtTick(stakedPositions[0].tickLower),
            TickMath.getSqrtRatioAtTick(stakedPositions[0].tickUpper),
            stakedPositions[0].liquidity + 1
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

        nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
            amount0 + 1,
            amount1 + 1,
            unstakedPositions[0].tickLower,
            unstakedPositions[0].tickUpper,
            tickSpacing,
            users.alice
        );

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
