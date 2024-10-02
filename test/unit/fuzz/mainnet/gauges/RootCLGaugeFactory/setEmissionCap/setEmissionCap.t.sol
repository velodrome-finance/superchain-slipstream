// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract SetEmissionCapIntegrationFuzzTest is RootCLGaugeFactoryTest {
    function testFuzz_WhenCallerIsNotTheEmissionAdmin(address _caller) external {
        // It should revert with {NotAuthorized}
        vm.assume(_caller != rootGaugeFactory.emissionAdmin());

        vm.prank(_caller);
        vm.expectRevert(bytes("NA"));
        rootGaugeFactory.setEmissionCap({_gauge: address(0), _emissionCap: 1000});
    }

    modifier whenCallerIsTheEmissionAdmin() {
        vm.startPrank(rootGaugeFactory.emissionAdmin());
        _;
    }

    function testFuzz_WhenGaugeIsNotTheZeroAddress(address _gauge, uint256 _emissionCap)
        external
        whenCallerIsTheEmissionAdmin
    {
        // It should set the new emission cap for the gauge
        // It should emit a {SetEmissionCap} event
        vm.assume(_gauge != address(0));

        vm.expectEmit(address(rootGaugeFactory));
        emit SetEmissionCap({gauge: _gauge, newEmissionCap: _emissionCap});
        rootGaugeFactory.setEmissionCap({_gauge: _gauge, _emissionCap: _emissionCap});

        // @dev If `emissionCap` is set to 0, `defaultCap` should be returned
        _emissionCap = _emissionCap == 0 ? rootGaugeFactory.defaultCap() : _emissionCap;
        assertEq(rootGaugeFactory.emissionCaps(_gauge), _emissionCap);
    }
}
