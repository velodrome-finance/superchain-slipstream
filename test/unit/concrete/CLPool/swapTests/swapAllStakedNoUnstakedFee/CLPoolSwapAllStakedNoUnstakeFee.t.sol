pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../BaseFixture.sol";
import {CLPoolSwapTests} from "../CLPoolSwapTests.t.sol";
import "forge-std/StdJson.sol";
import {CLLeafGauge} from "contracts/gauge/CLLeafGauge.sol";

/// Changes of note: execution price was scaled by 10**39 as Solidity has no native support for decimals.
/// Execution price is a string field as it also contains "-Infinity" and "NaN" values
/// poolPriceAfter and poolPriceBefore are stored as X96 pool price values (not sqrtPrice)
abstract contract CLPoolSwapAllStakedNoUnstakeFeeTest is CLPoolSwapTests {
    using stdJson for string;

    function setUp() public virtual override {
        super.setUp();

        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(
                root, "/test/unit/concrete/CLPool/swapTests/swapAllStakedNoUnstakedFee/swap_assert_all_staked.json"
            )
        );

        jsonConstants = vm.readFile(path);

        deal(address(token0), users.alice, TOKEN_2_TO_255);
        deal(address(token1), users.alice, TOKEN_2_TO_255);

        vm.startPrank(users.alice);

        labelContracts();
    }

    function assertSwapData(AssertSwapData memory asd, SuccessfulSwap memory ss) internal override {
        assertEq(asd.amount0Before, ss.amount0Before);
        assertEq(asd.amount1Before, ss.amount1Before);
        assertEq(asd.amount0Delta, ss.amount0Delta);
        assertEq(asd.amount1Delta, ss.amount1Delta);
        assertEq(asd.feeGrowthGlobal0X128Delta, ss.feeGrowthGlobal0X128Delta);
        assertEq(asd.feeGrowthGlobal1X128Delta, ss.feeGrowthGlobal1X128Delta);
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
        assertApproxEqAbs(asd.gaugeFeesToken0, ss.gaugeFeesToken0, 36);
        assertApproxEqAbs(asd.gaugeFeesToken1, ss.gaugeFeesToken1, 36);
    }

    function burnPosition() internal override {
        uint256 positionsLength = stakedPositions.length;
        vm.startPrank(address(nft));
        for (uint256 i = 0; i < positionsLength; i++) {
            Position memory position = stakedPositions[i];
            CLPool(poolSetup.pool).burn(position.tickLower, position.tickUpper, position.liquidity, poolSetup.gauge);
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
        addRewardToGauge(address(leafVoter), address(gauge), 1e18);
    }
}
