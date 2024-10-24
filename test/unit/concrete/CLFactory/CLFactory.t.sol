pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseForkFixture.sol";

contract CLFactoryTest is BaseForkFixture {
    function test_InitialState() public view virtual {
        assertEq(address(leafPoolFactory.voter()), address(leafVoter));
        assertEq(leafPoolFactory.poolImplementation(), address(leafPoolImplementation));
        assertEq(leafPoolFactory.owner(), users.owner);
        assertEq(leafPoolFactory.swapFeeModule(), address(customSwapFeeModule));
        assertEq(leafPoolFactory.unstakedFeeModule(), address(customUnstakedFeeModule));
        assertEq(leafPoolFactory.swapFeeManager(), users.feeManager);
        assertEq(leafPoolFactory.unstakedFeeManager(), users.feeManager);
        assertEq(leafPoolFactory.allPoolsLength(), 1);

        assertEqUint(leafPoolFactory.defaultUnstakedFee(), 100_000);
        assertEqUint(leafPoolFactory.tickSpacingToFee(TICK_SPACING_STABLE), 100);
        assertEqUint(leafPoolFactory.tickSpacingToFee(TICK_SPACING_LOW), 500);
        assertEqUint(leafPoolFactory.tickSpacingToFee(TICK_SPACING_MEDIUM), 500);
        assertEqUint(leafPoolFactory.tickSpacingToFee(TICK_SPACING_HIGH), 3_000);
        assertEqUint(leafPoolFactory.tickSpacingToFee(TICK_SPACING_VOLATILE), 10_000);
    }
}
