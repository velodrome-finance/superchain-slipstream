pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../BaseForkFixture.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLPoolSwapTests} from "../CLPoolSwapTests.t.sol";
import "forge-std/StdJson.sol";
import {CLLeafGauge} from "contracts/gauge/CLLeafGauge.sol";

/// Changes of note: execution price was scaled by 10**39 as Solidity has no native support for decimals.
/// Execution price is a string field as it also contains "-Infinity" and "NaN" values
/// poolPriceAfter and poolPriceBefore are stored as X96 pool price values (not sqrtPrice)
abstract contract CLPoolSwapPartiallyStakedWithUnstakeFeeTest is CLPoolSwapTests {
    using stdJson for string;

    function setUp() public virtual override {
        super.setUp();

        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(
                root,
                "/test/unit/concrete/CLPool/swapTests/swapPartiallyStakedWithUnstakedFee/swap_assert_partially_staked_with_fee.json"
            )
        );

        jsonConstants = vm.readFile(path);

        deal(address(token0), users.alice, TOKEN_2_TO_255);
        deal(address(token1), users.alice, TOKEN_2_TO_255);

        vm.startPrank(users.alice);

        labelContracts();
    }

    function assertSwapData(AssertSwapData memory asd, SuccessfulSwap memory ss) internal pure override {
        assertApproxEqAbs(asd.amount0Before, ss.amount0Before, 1);
        assertApproxEqAbs(asd.amount1Before, ss.amount1Before, 1);
        assertApproxEqAbs(asd.amount0Delta, ss.amount0Delta, 1);
        assertApproxEqAbs(asd.amount1Delta, ss.amount1Delta, 1);
        // 8171200476872495323171 is ~ 24 unit of token for 1e18 liquidity (sufficient for most of the tests)
        assertApproxEqAbs(asd.feeGrowthGlobal0X128Delta, ss.feeGrowthGlobal0X128Delta, 8171200476872495323171);
        assertApproxEqAbs(asd.feeGrowthGlobal1X128Delta, ss.feeGrowthGlobal1X128Delta, 8171200476872495323171);
        assertEq(asd.tickBefore, ss.tickBefore);
        assertEq(uint256(asd.poolPriceBefore), uint256(ss.poolPriceBeforeX96));
        assertEq(asd.tickAfter, ss.tickAfter);
        assertApproxEqAbs(uint256(asd.poolPriceAfter), uint256(ss.poolPriceAfterX96), 1);
        if (asd.amount0Delta != 0) {
            int256 executionPrice = getScaledExecutionPrice(asd.amount1Delta, asd.amount0Delta);
            assertEq(executionPrice, int256(stringToUint(ss.executionPrice)));
        } else if (asd.amount1Delta == 0) {
            assertEq("NaN", ss.executionPrice);
        } else {
            assertEq("-Infinity", ss.executionPrice);
        }
        assertApproxEqAbs(asd.gaugeFeesToken0, ss.gaugeFeesToken0, 57);
        assertApproxEqAbs(asd.gaugeFeesToken1, ss.gaugeFeesToken1, 57);
    }

    function burnPosition() internal override {
        burnUnstakedPosition();
        burnStakedPosition();
    }

    function burnStakedPosition() internal {
        uint256 positionsLength = stakedPositions.length;
        vm.startPrank(address(nft));
        for (uint256 i = 0; i < positionsLength; i++) {
            Position memory position = stakedPositions[i];

            (uint128 liquidity,,,,) = CLPool(poolSetup.pool).positions(
                keccak256(abi.encodePacked(poolSetup.gauge, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
            );

            CLPool(poolSetup.pool).burn(position.tickLower, position.tickUpper, liquidity, poolSetup.gauge);
            CLPool(poolSetup.pool).collect(
                users.alice,
                position.tickLower,
                position.tickUpper,
                type(uint128).max,
                type(uint128).max,
                poolSetup.gauge
            );
        }

        // sanity check
        skip(WEEK);
        addRewardToLeafGauge(address(gauge), 1e18);
    }

    function burnUnstakedPosition() internal {
        uint256 positionsLength = unstakedPositions.length;
        vm.startPrank(address(nft));
        for (uint256 i = 0; i < positionsLength; i++) {
            Position memory position = unstakedPositions[i];

            (uint128 liquidity,,,,) = CLPool(poolSetup.pool).positions(
                keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
            );

            CLPool(poolSetup.pool).burn(position.tickLower, position.tickUpper, liquidity, address(nft));
            CLPool(poolSetup.pool).collect(
                users.alice, position.tickLower, position.tickUpper, type(uint128).max, type(uint128).max, address(nft)
            );
        }
    }
}
