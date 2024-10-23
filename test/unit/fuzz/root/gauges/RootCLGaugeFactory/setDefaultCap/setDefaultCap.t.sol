// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract SetDefaultCapIntegrationFuzzTest is RootCLGaugeFactoryTest {
    function testFuzz_WhenCallerIsNotTheEmissionAdmin(address _caller) external {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != rootGaugeFactory.emissionAdmin());

        vm.prank(_caller);
        vm.expectRevert(bytes("NA"));
        rootGaugeFactory.setDefaultCap({_defaultCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function testFuzz_WhenDefaultCapIsNotZero(uint256 _defaultCap) external whenCallerIsTheEmissionAdmin {
        // It should set the new default cap for gauges
        // It should emit a {DefaultCapSet} event
        _defaultCap = bound(_defaultCap, 1, type(uint256).max);

        vm.expectEmit(address(rootGaugeFactory));
        emit DefaultCapSet({newDefaultCap: _defaultCap});
        rootGaugeFactory.setDefaultCap({_defaultCap: _defaultCap});

        assertEq(rootGaugeFactory.defaultCap(), _defaultCap);
    }
}
