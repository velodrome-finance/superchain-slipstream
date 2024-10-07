// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is RootCLGaugeFactoryTest {
    function setUp() public override {
        super.setUp();

        rootPool = RootCLPool(
            rootPoolFactory.createPool({
                chainid: leafChainId,
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_10
            })
        );

        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), amount: MESSAGE_FEE});
    }

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
        rootGauge = RootCLGauge(
            rootGaugeFactory.createGauge(address(0), address(rootPool), address(rootFVR), address(rewardToken), true)
        );

        assertEq(rootGauge.gaugeFactory(), address(rootGaugeFactory));
        assertEq(rootGauge.rewardToken(), address(rewardToken));
        assertEq(rootGauge.xerc20(), address(xVelo));
        assertEq(rootGauge.voter(), address(rootVoter));
        assertEq(rootGauge.lockbox(), address(rootLockbox));
        assertEq(rootGauge.bridge(), address(rootMessageBridge));
        assertEq(rootGauge.chainid(), leafChainId);
        assertEq(rootGauge.minter(), address(minter));

        vm.selectFork({forkId: leafId});
        address pool = Clones.predictDeterministicAddress({
            deployer: address(poolFactory),
            master: poolFactory.poolImplementation(),
            salt: keccak256(abi.encode(address(token0), address(token1), TICK_SPACING_10))
        });

        vm.expectEmit(address(poolFactory));
        emit PoolCreated({token0: address(token0), token1: address(token1), tickSpacing: TICK_SPACING_10, pool: pool});
        vm.expectEmit(true, true, true, false, address(leafVoter));
        emit GaugeCreated({
            poolFactory: address(poolFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            gaugeFactory: address(leafGaugeFactory),
            pool: address(pool),
            bribeVotingReward: address(13),
            feeVotingReward: address(12),
            gauge: address(rootGauge)
        });
        leafMailbox.processNextInboundMessage();

        assertTrue(poolFactory.isPool(pool));

        leafPool = CLPool(pool);
        assertEq(leafPool.token0(), address(token0));
        assertEq(leafPool.token1(), address(token1));
        assertEq(leafPool.tickSpacing(), TICK_SPACING_10);

        leafGauge = LeafCLGauge(leafVoter.gauges(pool));
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));

        assertEq(address(leafGauge), address(rootGauge));
    }
}
