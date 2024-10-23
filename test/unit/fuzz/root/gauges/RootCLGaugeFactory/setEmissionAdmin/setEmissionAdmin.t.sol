// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract SetEmissionAdminIntegrationFuzzTest is RootCLGaugeFactoryTest {
    function testFuzz_WhenCallerIsNotTheEmissionAdmin(address _caller) external {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != rootGaugeFactory.emissionAdmin());

        vm.prank(_caller);
        vm.expectRevert(bytes("NA"));
        rootGaugeFactory.setEmissionAdmin({_admin: _caller});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.prank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function testFuzz_WhenAdminIsNotTheZeroAddress(address _emissionAdmin) external whenCallerIsTheEmissionAdmin {
        // It should set the new emission admin
        // It should emit a {EmissionAdminSet} event
        vm.assume(_emissionAdmin != address(0));

        vm.expectEmit(address(rootGaugeFactory));
        emit EmissionAdminSet({emissionAdmin: _emissionAdmin});
        rootGaugeFactory.setEmissionAdmin({_admin: _emissionAdmin});

        assertEq(rootGaugeFactory.emissionAdmin(), _emissionAdmin);
    }
}
