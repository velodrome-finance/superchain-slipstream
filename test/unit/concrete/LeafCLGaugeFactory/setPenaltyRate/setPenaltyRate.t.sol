pragma solidity ^0.7.6;
pragma abicoder v2;

import "../LeafCLGaugeFactory.t.sol";

contract SetPenaltyRateConcreteUnitTest is LeafCLGaugeFactoryTest {
    function test_WhenTheCallerIsNotTheGaugeStakeManager() external {
        // It should revert with {NA}
        vm.startPrank({msgSender: users.charlie});
        vm.expectRevert(abi.encodePacked("NA"));
        leafGaugeFactory.setPenaltyRate({_penaltyRate: 5000});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function test_WhenThePenaltyRateExceedsTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should revert with {MR}
        uint256 tooHigh = leafGaugeFactory.MAX_BPS() + 1;
        vm.startPrank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("MR"));
        leafGaugeFactory.setPenaltyRate({_penaltyRate: tooHigh});
    }

    function test_WhenThePenaltyRateDoesNotExceedTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should set the penalty rate
        // It should emit a {SetPenaltyRate} event
        vm.prank({msgSender: users.owner});
        vm.expectEmit(address(leafGaugeFactory));
        emit SetPenaltyRate({_penaltyRate: 5000});
        leafGaugeFactory.setPenaltyRate({_penaltyRate: 5000});

        assertEq(leafGaugeFactory.penaltyRate(), 5000);
    }
}
