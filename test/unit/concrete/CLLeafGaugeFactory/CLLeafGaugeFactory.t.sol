pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseFixture.sol";

contract CLLeafGaugeFactoryTest is BaseFixture {
    function test_InitialState() public {
        assertEq(leafGaugeFactory.voter(), address(leafVoter));
        // assertEq(leafGaugeFactory.implementation(), address(gaugeImplementation));
    }
}
