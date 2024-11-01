// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract SetEmissionCapIntegrationConcreteTest is RootCLGaugeFactoryTest {
    address gauge;

    function test_WhenCallerIsNotTheEmissionAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(bytes("NA"));
        rootGaugeFactory.setEmissionCap({_gauge: gauge, _emissionCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenGaugeIsTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should revert with {ZeroAddress}
        vm.expectRevert(bytes("ZA"));
        rootGaugeFactory.setEmissionCap({_gauge: gauge, _emissionCap: 1000});
    }

    modifier whenGaugeIsNotTheZeroAddress() {
        gauge = address(rootGauge);
        _;
    }

    function test_WhenEmissionCapIsGreaterThanMaxBps()
        external
        whenCallerIsTheEmissionAdmin
        whenGaugeIsNotTheZeroAddress
    {
        // It should revert with {MaxCap}
        vm.expectRevert(bytes("MC"));
        rootGaugeFactory.setEmissionCap({_gauge: gauge, _emissionCap: 10_001});
    }

    function test_WhenEmissionCapIsLessOrEqualToMaxBps()
        external
        whenCallerIsTheEmissionAdmin
        whenGaugeIsNotTheZeroAddress
    {
        // It should set the new emission cap for the gauge
        // It should emit a {EmissionCapSet} event
        assertEq(rootGaugeFactory.emissionCaps(gauge), 100);

        vm.expectEmit(address(rootGaugeFactory));
        emit EmissionCapSet({gauge: gauge, newEmissionCap: 1000});
        rootGaugeFactory.setEmissionCap({_gauge: gauge, _emissionCap: 1000});

        assertEq(rootGaugeFactory.emissionCaps(gauge), 1000);
    }
}
