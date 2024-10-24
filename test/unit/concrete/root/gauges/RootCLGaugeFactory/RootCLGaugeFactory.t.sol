// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../BaseForkFixture.sol";

abstract contract RootCLGaugeFactoryTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: rootId});
    }

    function test_InitialState() public view {
        assertEq(rootGaugeFactory.voter(), address(rootVoter));
        assertEq(rootGaugeFactory.xerc20(), address(rootXVelo));
        assertEq(rootGaugeFactory.lockbox(), address(rootLockbox));
        assertEq(rootGaugeFactory.messageBridge(), address(rootMessageBridge));
        assertEq(rootGaugeFactory.poolFactory(), address(rootPoolFactory));
        assertEq(rootGaugeFactory.votingRewardsFactory(), address(rootVotingRewardsFactory));
        assertEq(rootGauge.rewardToken(), address(rewardToken));
        assertEq(rootGauge.minter(), address(minter));
        assertEq(rootGaugeFactory.notifyAdmin(), users.owner);
        assertEq(rootGaugeFactory.emissionAdmin(), users.owner);
        assertEq(rootGaugeFactory.weeklyEmissions(), 0);
        assertEq(rootGaugeFactory.activePeriod(), 0);
        assertEq(rootGaugeFactory.defaultCap(), 100);
        assertEq(rootGaugeFactory.emissionCaps({_gauge: address(rootGauge)}), 100);
    }
}
