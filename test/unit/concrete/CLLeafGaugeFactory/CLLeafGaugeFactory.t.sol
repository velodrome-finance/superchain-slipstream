pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseForkFixture.sol";

contract CLLeafGaugeFactoryTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(leafGaugeFactory.voter(), address(leafVoter));
        assertEq(leafGaugeFactory.xerc20(), address(xVelo));
        assertEq(leafGaugeFactory.bridge(), address(leafMessageBridge));
        assertEq(leafGaugeFactory.nft(), address(nft));
    }
}
