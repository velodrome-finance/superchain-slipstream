pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../BaseForkFixture.sol";

abstract contract CLRootGaugeTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: rootId});
    }
}
