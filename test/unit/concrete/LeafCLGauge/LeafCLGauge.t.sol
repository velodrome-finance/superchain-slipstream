pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseForkFixture.sol";
import {Position} from "contracts/core/libraries/Position.sol";

contract LeafCLGaugeTest is BaseForkFixture {
    function test_InitialState() public view {
        assertEq(address(leafGauge.nft()), address(nft));
        assertEq(address(leafGauge.voter()), address(leafVoter));
        assertEq(address(leafGauge.pool()), address(leafPool));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));
        assertEq(leafGauge.feesVotingReward(), leafVoter.gaugeToFees(address(leafGauge)));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.token0(), address(token0));
        assertEq(leafGauge.token1(), address(token1));
        assertEq(leafGauge.tickSpacing(), 1);
        assertTrue(leafGauge.isPool());
    }
}
