// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "../../../BaseForkFixture.sol";
import {TickTest, Tick} from "contracts/core/test/TickTest.sol";

contract TickTestBase is BaseForkFixture {
    TickTest public tickTest;

    function setUp() public virtual override {
        super.setUp();

        tickTest = new TickTest();
    }
}
