pragma solidity ^0.7.6;
pragma abicoder v2;

import "../BaseForkFixture.sol";

contract NotifyRewardWithoutClaimForkTest is BaseForkFixture {
    function setUp() public override {
        super.setUp();

        vm.selectFork(rootId);

        rootPool = RootCLPool(
            rootPoolFactory.createPool({
                chainid: leafChainId,
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60
            })
        );
        vm.prank({msgSender: rootVoter.governor(), txOrigin: users.alice});
        rootGauge =
            RootCLGauge(rootVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(rootPool)}));

        // set up leaf pool & gauge by processing pending `createGauge` message in mailbox
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        leafPool = CLPool(
            leafPoolFactory.getPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );
        leafGauge = LeafCLGauge(leafVoter.gauges(address(leafPool)));

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(leafPool), 420);

        skipToNextEpoch(0);

        setLimits({_rootBufferCap: rootXVelo.minBufferCap() + 1, _leafBufferCap: rootXVelo.minBufferCap() + 1});
    }

    function testFork_NotifyRewardWithoutClaimResetsRewardRateInKilledGauge() public {
        skipTime(1 days);

        uint256 reward = TOKEN_1;
        vm.startPrank(users.alice);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(leafGauge), tokenId);
        leafGauge.deposit(tokenId);
        vm.stopPrank();

        vm.selectFork({forkId: rootId});
        deal(address(rewardToken), address(rootVoter), reward);
        vm.startPrank(address(rootVoter));
        rewardToken.approve(address(rootGauge), reward);
        rootGauge.notifyRewardAmount(reward);
        vm.stopPrank();

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        uint256 gaugeRewardTokenBalance = rootXVelo.balanceOf(address(leafGauge));
        assertEq(gaugeRewardTokenBalance, reward);

        assertEq(leafGauge.rewardRate(), reward / 6 days);
        assertEq(leafGauge.lastUpdateTime(tokenId), block.timestamp);
        assertEq(leafGauge.periodFinish(), block.timestamp + 6 days);

        vm.prank(address(leafMessageModule));
        leafVoter.killGauge(address(leafGauge));

        skipToNextEpoch(0);

        vm.selectFork({forkId: rootId});
        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, 604_800);
        rewardToken.approve(address(rootGauge), 604_800);
        rootGauge.notifyRewardWithoutClaim(604_800); // requires minimum value of 604800

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafGauge.rewardRate(), 1); // reset to token amount
        assertEq(leafGauge.lastUpdateTime(tokenId), block.timestamp - 6 days);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }
}
