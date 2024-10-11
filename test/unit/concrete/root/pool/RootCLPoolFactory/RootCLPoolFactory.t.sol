// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../BaseForkFixture.sol";

contract RootCLPoolFactoryTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: rootId});
    }

    function test_InitialState() public view {
        assertEq(rootPoolFactory.poolImplementation(), address(rootPoolImplementation));
        assertEq(rootPoolFactory.bridge(), address(rootMessageBridge));
        assertEq(rootPoolFactory.owner(), users.owner);
    }
}
