// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../BaseFixture.sol";

contract RootCLPoolFactoryTest is BaseFixture {
    function test_InitialState() public view {
        assertEq(rootPoolFactory.poolImplementation(), address(rootPoolImplementation));
        assertEq(rootPoolFactory.bridge(), address(rootMessageBridge));
        assertEq(rootPoolFactory.owner(), users.owner);
    }
}
