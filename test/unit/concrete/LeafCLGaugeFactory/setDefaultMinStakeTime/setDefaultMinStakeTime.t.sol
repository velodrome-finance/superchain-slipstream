pragma solidity ^0.7.6;
pragma abicoder v2;

import "../LeafCLGaugeFactory.t.sol";

contract SetDefaultMinStakeTimeConcreteUnitTest is LeafCLGaugeFactoryTest {
    function test_WhenTheCallerIsNotTheGaugeStakeManager() external {
        // It should revert with {NA}
        vm.prank({msgSender: users.charlie});
        vm.expectRevert(abi.encodePacked("NA"));
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: 60});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function test_WhenTheMinStakeTimeExceedsTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should revert with {MS}
        uint256 tooHigh = leafGaugeFactory.MAX_MIN_STAKE_TIME() + 1;
        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("MS"));
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: tooHigh});
    }

    function test_WhenTheMinStakeTimeDoesNotExceedTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should set the default min stake time
        // It should emit a {SetDefaultMinStakeTime} event
        vm.prank({msgSender: users.owner});
        vm.expectEmit(address(leafGaugeFactory));
        emit SetDefaultMinStakeTime({_minStakeTime: 120});
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: 120});

        assertEq(leafGaugeFactory.defaultMinStakeTime(), 120);
    }
}
