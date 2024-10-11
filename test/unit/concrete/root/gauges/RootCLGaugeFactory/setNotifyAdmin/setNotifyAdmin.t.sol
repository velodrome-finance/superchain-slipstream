// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract SetNotifyAdminIntegrationConcreteTest is RootCLGaugeFactoryTest {
    function test_WhenCallerIsNotTheNotifyAdmin() external {
        // It should revert with NotAuthorized
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        rootGaugeFactory.setNotifyAdmin({_admin: users.charlie});
    }

    modifier whenCallerIsTheNotifyAdmin() {
        vm.prank(rootGaugeFactory.notifyAdmin());
        _;
    }

    function test_WhenAdminIsTheZeroAddress() external whenCallerIsTheNotifyAdmin {
        // It should revert with ZeroAddress
        vm.expectRevert(abi.encodePacked("ZA"));
        rootGaugeFactory.setNotifyAdmin({_admin: address(0)});
    }

    function test_WhenAdminIsNotTheZeroAddress() external whenCallerIsTheNotifyAdmin {
        // It should set the new notify admin
        // It should emit a {SetNotifyAdmin} event
        vm.expectEmit(address(rootGaugeFactory));
        emit SetNotifyAdmin({notifyAdmin: users.alice});
        rootGaugeFactory.setNotifyAdmin({_admin: users.alice});

        assertEq(rootGaugeFactory.notifyAdmin(), users.alice);
    }
}
