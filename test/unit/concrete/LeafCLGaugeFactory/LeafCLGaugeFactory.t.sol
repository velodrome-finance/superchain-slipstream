pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseForkFixture.sol";

contract LeafCLGaugeFactoryTest is BaseForkFixture {
    function test_InitialState() public {
        assertEq(leafGaugeFactory.voter(), address(leafVoter));
        assertEq(leafGaugeFactory.xerc20(), address(leafXVelo));
        assertEq(leafGaugeFactory.bridge(), address(leafMessageBridge));
        assertEq(leafGaugeFactory.nft(), address(nft));
        assertEq(leafGaugeFactory.gaugeStakeManager(), users.owner);
        assertEq(leafGaugeFactory.defaultMinStakeTime(), 0);
        assertEq(leafGaugeFactory.penaltyRate(), 0);
    }
}
