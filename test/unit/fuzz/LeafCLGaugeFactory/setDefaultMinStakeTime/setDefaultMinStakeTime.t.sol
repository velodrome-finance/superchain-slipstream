pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../concrete/LeafCLGaugeFactory/LeafCLGaugeFactory.t.sol";

contract SetDefaultMinStakeTimeConcreteFuzzTest is LeafCLGaugeFactoryTest {
    function testFuzz_WhenTheCallerIsNotTheGaugeStakeManager(address _caller) external {
        // It should revert with {NA}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodePacked("NA"));
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: 60});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function testFuzz_WhenTheMinStakeTimeExceedsTheMaximum(uint256 _minStakeTime)
        external
        whenTheCallerIsTheGaugeStakeManager
    {
        // It should revert with {MS}
        uint256 tooHigh = leafGaugeFactory.MAX_MIN_STAKE_TIME() + 1;
        _minStakeTime = bound(_minStakeTime, tooHigh, type(uint256).max);
        vm.prank(users.owner);
        vm.expectRevert(abi.encodePacked("MS"));
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: _minStakeTime});
    }

    function testFuzz_WhenTheMinStakeTimeDoesNotExceedTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // not fuzzed: simple storage assignment, boundary covered by testFuzz_WhenTheMinStakeTimeExceedsTheMaximum
    }
}
