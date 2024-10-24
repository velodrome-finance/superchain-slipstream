pragma solidity ^0.7.6;
pragma abicoder v2;

import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import "../../../../BaseForkFixture.sol";

contract CustomSwapFeeModuleTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();
        customSwapFeeModule = new CustomSwapFeeModule({_factory: address(leafPoolFactory)});

        vm.prank(users.feeManager);
        leafPoolFactory.setSwapFeeModule({_swapFeeModule: address(customSwapFeeModule)});

        vm.label({account: address(customSwapFeeModule), newLabel: "Custom Swap Fee Module"});
    }

    function test_InitialState() public view {
        assertEq(customSwapFeeModule.MAX_FEE(), 30_000);
        assertEq(address(customSwapFeeModule.factory()), address(leafPoolFactory));
    }
}
