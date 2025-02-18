pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract SetSwapFeeModule is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        resetPrank({msgSender: users.charlie});
        vm.expectRevert();
        leafPoolFactory.setSwapFeeModule({_swapFeeModule: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        leafPoolFactory.setSwapFeeModule({_swapFeeModule: address(0)});
    }

    function test_SetSwapFeeModule() public {
        vm.expectEmit(true, true, false, false, address(leafPoolFactory));
        emit SwapFeeModuleChanged({oldFeeModule: address(customSwapFeeModule), newFeeModule: users.alice});
        leafPoolFactory.setSwapFeeModule({_swapFeeModule: users.alice});

        assertEq(leafPoolFactory.swapFeeModule(), users.alice);
    }
}
