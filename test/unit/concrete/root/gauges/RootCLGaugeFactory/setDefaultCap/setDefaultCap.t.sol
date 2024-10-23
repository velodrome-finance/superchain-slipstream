// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract SetDefaultCapIntegrationConcreteTest is RootCLGaugeFactoryTest {
    function test_WhenCallerIsNotTheEmissionAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(bytes("NA"));
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenDefaultCapIsZero() external whenCallerIsTheEmissionAdmin {
        // It should revert with {ZeroDefaultCap}
        vm.expectRevert(bytes("ZDC"));
        rootGaugeFactory.setDefaultCap({_defaultCap: 0});
    }

    function test_WhenDefaultCapIsNotZero() external whenCallerIsTheEmissionAdmin {
        // It should set the new default cap for gauges
        // It should emit a {DefaultCapSet} event
        vm.expectEmit(address(rootGaugeFactory));
        emit DefaultCapSet({newDefaultCap: 1000});
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});

        assertEq(rootGaugeFactory.defaultCap(), 1000);
    }
}
