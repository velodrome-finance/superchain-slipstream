// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLRootGaugeFactory.t.sol";

contract CreateGaugeIntegrationConcreteTest is CLRootGaugeFactoryTest {
    function setUp() public override {
        super.setUp();

        // we use stable = true to avoid collision with existing pool
        rootPool = RootCLPool(
            rootPoolFactory.createPool({
                chainid: leafChainId,
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: 10
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
            salt: keccak256(abi.encode(address(token0), address(token1), int24(1)))
        });

        vm.expectEmit(address(poolFactory));
        emit PoolCreated({token0: address(token0), token1: address(token1), tickSpacing: int24(1), pool: pool});
        vm.expectEmit(true, true, true, false, address(leafVoter));
        emit GaugeCreated({
            poolFactory: address(poolFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            gaugeFactory: address(leafGaugeFactory),
            pool: pool,
            bribeVotingReward: address(13),
            feeVotingReward: address(12),
            gauge: address(11),
            creator: address(leafMessageBridge)
        });
        leafMailbox.processNextInboundMessage();

        assertTrue(poolFactory.isPool(pool));

        leafPool = CLPool(pool);
        assertEq(leafPool.token0(), address(token0));
        assertEq(leafPool.token1(), address(token1));
        assertEq(uint256(uint24(leafPool.tickSpacing())), 1);

        leafGauge = CLLeafGauge(leafVoter.gauges(pool));
        assertNotEq(leafGauge.feesVotingReward(), address(0));
        assertEq(leafGauge.rewardToken(), address(leafXVelo));
        assertEq(leafGauge.bridge(), address(leafMessageBridge));

        assertEq(address(leafGauge), address(rootGauge));
    }
}
