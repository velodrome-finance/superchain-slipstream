// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract SetEmissionCapIntegrationConcreteTest is RootCLGaugeFactoryTest {
    function test_WhenCallerIsNotTheEmissionAdmin() external {
        // It should revert with {NotAuthorized}
        vm.prank(users.charlie);
        vm.expectRevert(bytes("NA"));
        rootGaugeFactory.setEmissionCap({_gauge: address(0), _emissionCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function test_WhenGaugeIsTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should revert with {ZeroAddress}
        vm.expectRevert(bytes("ZA"));
        rootGaugeFactory.setEmissionCap({_gauge: address(0), _emissionCap: 1000});
    }

    function test_WhenGaugeIsNotTheZeroAddress() external whenCallerIsTheEmissionAdmin {
        // It should set the new emission cap for the gauge
        // It should emit a {SetEmissionCap} event
        assertEq(rootGaugeFactory.emissionCaps(address(rootGauge)), 100);

        vm.expectEmit(address(rootGaugeFactory));
        emit SetEmissionCap({gauge: address(rootGauge), newEmissionCap: 1000});
        rootGaugeFactory.setEmissionCap({_gauge: address(rootGauge), _emissionCap: 1000});

        assertEq(rootGaugeFactory.emissionCaps(address(rootGauge)), 1000);
    }
}
