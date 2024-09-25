// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLRootGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is CLRootGaugeFactoryTest {
    function test_WhenTheCallerIsNotVoter() external {
        // It reverts with NotVoter
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodePacked("NV"));
        rootGaugeFactory.createGauge(address(0), address(rootPool), address(0), address(rewardToken), true);
    }

    function test_WhenTheCallerIsVoter() external {
        // It creates a new gauge on root chain
        // It should encode the root pool configuration
        // It should create new pool on leaf chain with same config
        // It should emit a {PoolCreated} event
        // It should call createGauge with leaf pool and factory on corresponding leaf voter
        // It should create a new gauge on leaf chain with same address as root gauge
        // It should emit a {GaugeCreated} event
        vm.prank(address(rootVoter));
        (address rootFVR,) = rootVotingRewardsFactory.createRewards(address(0), new address[](0));
        vm.prank({msgSender: address(rootVoter), txOrigin: users.alice});
        CLRootGauge rootGauge = CLRootGauge(
            rootGaugeFactory.createGauge(address(0), address(rootPool), address(rootFVR), address(rewardToken), true)
        );

        assertEq(rootGauge.gaugeFactory(), address(rootGaugeFactory));
        assertEq(rootGauge.rewardToken(), address(rewardToken));
        assertEq(rootGauge.xerc20(), address(xVelo));
        assertEq(rootGauge.voter(), address(rootVoter));
        assertEq(rootGauge.lockbox(), address(rootLockbox));
        assertEq(rootGauge.bridge(), address(rootMessageBridge));
        assertEq(rootGauge.chainid(), leafChainId);

        // vm.selectFork({forkId: leafId});
        //
        // address pool = Clones.predictDeterministicAddress({
        //     deployer: address(leafPoolFactory),
        //     implementation: leafPoolFactory.implementation(),
        //     salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        // });
        // assertFalse(leafPoolFactory.isPool(pool));
        //
        // vm.expectEmit(address(leafPoolFactory));
        // emit IPoolFactory.PoolCreated(
        //     address(token0), address(token1), true, pool, leafPoolFactory.allPoolsLength() + 1
        // );
        // vm.expectEmit(true, true, true, false, address(leafVoter));
        // emit ILeafVoter.GaugeCreated({
        //     poolFactory: address(leafPoolFactory),
        //     votingRewardsFactory: address(leafVotingRewardsFactory),
        //     gaugeFactory: address(leafGaugeFactory),
        //     pool: pool,
        //     bribeVotingReward: address(13),
        //     feeVotingReward: address(12),
        //     gauge: address(11),
        //     creator: address(leafMessageBridge)
        // });
        // leafMailbox.processNextInboundMessage();
        //
        // assertTrue(leafPoolFactory.isPool(pool));
        //
        // leafPool = Pool(pool);
        // assertEq(leafPool.token0(), address(token0));
        // assertEq(leafPool.token1(), address(token1));
        // assertTrue(leafPool.stable());
        //
        // leafGauge = LeafGauge(leafVoter.gauges(pool));
        // assertEq(leafGauge.stakingToken(), pool);
        // assertNotEq(leafGauge.feesVotingReward(), address(0));
        // assertEq(leafGauge.rewardToken(), address(leafXVelo));
        // assertEq(leafGauge.bridge(), address(leafMessageBridge));
        // assertEq(leafGauge.gaugeFactory(), address(leafGaugeFactory));
        //
        // assertEq(address(leafGauge), address(rootGauge));
    }
}
