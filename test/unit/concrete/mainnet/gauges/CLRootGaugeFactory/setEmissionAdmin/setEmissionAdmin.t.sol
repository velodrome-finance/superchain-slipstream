// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLRootGaugeFactory.t.sol";

contract SetEmissionAdminIntegrationConcreteTest is CLRootGaugeFactoryTest {
    function test_WhenCallerIsNotTheEmissionAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(bytes("NA"));
        rootGaugeFactory.setEmissionAdmin({_admin: users.charlie});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.prank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenAdminIsTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should revert with {ZeroAddress}
        vm.expectRevert(bytes("ZA"));
        rootGaugeFactory.setEmissionAdmin({_admin: address(0)});
    }

    function test_WhenAdminIsNotTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should set the new emission admin
        // It should emit a {SetEmissionAdmin} event
        vm.expectEmit(address(rootGaugeFactory));
        emit SetEmissionAdmin({emissionAdmin: users.alice});
        rootGaugeFactory.setEmissionAdmin({_admin: users.alice});

        assertEq(rootGaugeFactory.emissionAdmin(), users.alice);
    }
}
