pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract SetOwnerTest is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.owner});
    }

    function test_RevertIf_NotOwner() public {
        resetPrank({msgSender: users.charlie});
        vm.expectRevert();
        leafPoolFactory.setOwner({_owner: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        leafPoolFactory.setOwner({_owner: address(0)});
    }

    function test_SetOwner() public {
        vm.expectEmit(true, true, false, false, address(leafPoolFactory));
        emit OwnerChanged({oldOwner: users.owner, newOwner: users.alice});
        leafPoolFactory.setOwner({_owner: users.alice});

        assertEq(leafPoolFactory.owner(), users.alice);
    }
}
