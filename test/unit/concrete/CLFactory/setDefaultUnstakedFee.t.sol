pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract SetDefaultUnstakedFee is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        resetPrank({msgSender: users.charlie});
        vm.expectRevert();
        leafPoolFactory.setDefaultUnstakedFee({_defaultUnstakedFee: 200_000});
    }

    function test_RevertIf_GreaterThanMax() public {
        vm.expectRevert();
        leafPoolFactory.setDefaultUnstakedFee({_defaultUnstakedFee: 500_001});
    }

    function test_SetDefaultUnstakedFee() public {
        vm.expectEmit(true, true, false, false, address(leafPoolFactory));
        emit DefaultUnstakedFeeChanged({oldUnstakedFee: 100_000, newUnstakedFee: 200_000});
        leafPoolFactory.setDefaultUnstakedFee({_defaultUnstakedFee: 200_000});

        assertEqUint(leafPoolFactory.defaultUnstakedFee(), 200_000);
    }
}
