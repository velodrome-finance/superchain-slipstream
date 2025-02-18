pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract SetUnstakedFeeModule is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        resetPrank({msgSender: users.charlie});
        vm.expectRevert();
        leafPoolFactory.setUnstakedFeeModule({_unstakedFeeModule: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        leafPoolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(0)});
    }

    function test_SetUnstakedFeeModule() public {
        vm.expectEmit(true, true, false, false, address(leafPoolFactory));
        emit UnstakedFeeModuleChanged({oldFeeModule: address(customUnstakedFeeModule), newFeeModule: users.alice});
        leafPoolFactory.setUnstakedFeeModule({_unstakedFeeModule: users.alice});

        assertEq(leafPoolFactory.unstakedFeeModule(), users.alice);
    }
}
