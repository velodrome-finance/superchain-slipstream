pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../BaseForkFixture.sol";
import "../../../contracts/periphery/libraries/TransferHelper.sol";
import {ISwapRouter, SwapRouter} from "../../../contracts/periphery/SwapRouter.sol";

contract GaugeFlowTest is BaseForkFixture {
    ISwapRouter public swapRouter;
    address public feesVotingReward;
    uint256 public warpTs;
    uint256 public EMISSION = TOKEN_1;
    address public largeTokenHolder = vm.addr(0x123454321);

    function setUp() public override {
        super.setUp();

        vm.selectFork(rootId);
        rootPool = RootCLPool(
            rootPoolFactory.createPool({
                chainid: leafChainId,
                tokenA: address(weth),
                tokenB: address(op),
                tickSpacing: TICK_SPACING_60
            })
        );
        vm.prank({msgSender: rootVoter.governor(), txOrigin: users.alice});
        rootGauge =
            RootCLGauge(rootVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: address(rootPool)}));
        feesVotingReward = rootVoter.gaugeToFees(address(rootGauge));

        // Early deposit of rewards on voter
        // will be used to send to the gauge each epoch
        deal(address(rewardToken), address(rootVoter), EMISSION * 100);
        vm.prank(address(rootVoter));
        rewardToken.approve(address(rootGauge), EMISSION * 100);

        // set up leaf pool & gauge by processing pending `createGauge` message in mailbox
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        leafPool =
            CLPool(leafPoolFactory.getPool({tokenA: address(weth), tokenB: address(op), tickSpacing: TICK_SPACING_60}));
        leafGauge = LeafCLGauge(leafVoter.gauges(address(leafPool)));

        swapRouter = new SwapRouter(address(leafPoolFactory), address(weth));

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(leafPool), 10_000);

        // Skip to next epoch
        skipToTimestamp(VelodromeTimeLibrary.epochNext(block.timestamp));

        setLimits({_rootBufferCap: TOKEN_1 * 1_000_000, _leafBufferCap: TOKEN_1 * 1_000_000});
    }

    //swaps a certain amount of token0 for token1 - only intended for testing purposes
    function doSwap(uint256 _amount, address user, bool token0In) internal returns (uint256 amountOut) {
        TransferHelper.safeApprove(token0In ? leafPool.token0() : leafPool.token1(), address(swapRouter), _amount);
        amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: token0In ? leafPool.token0() : leafPool.token1(),
                tokenOut: token0In ? leafPool.token1() : leafPool.token0(),
                tickSpacing: leafPool.tickSpacing(),
                recipient: user,
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function doSomeSwaps() internal {
        vm.startPrank(users.charlie);
        deal(address(weth), users.charlie, TOKEN_1 * 100);
        doSwap(TOKEN_1 * 100, users.charlie, true);

        skipToTimestamp({newTimestamp: warpTs + 1 hours});

        deal(address(op), users.charlie, TOKEN_1 * 10_000);
        doSwap(TOKEN_1 * 10000, users.charlie, false);
        vm.stopPrank();

        skipToTimestamp({newTimestamp: warpTs + 1 hours});
    }

    function checkEmissions(address user, uint256 tokenId, uint256 expectedBalance) internal {
        vm.startPrank(user);
        leafGauge.getReward(tokenId);
        assertEq(leafXVelo.balanceOf(user), expectedBalance);
        vm.stopPrank();
    }

    function checkFees(address user, uint256 tokenId, uint256 expectedBalanceWETH, uint256 expectedBalanceOP)
        internal
    {
        uint256 activeFork = vm.activeFork();

        selectForkAndSyncTimestamp({forkId: rootId});
        vm.startPrank(user);
        //claim fees rewards
        address[] memory feesVotingRewards = new address[](1);
        feesVotingRewards[0] = feesVotingReward;
        address[][] memory tokens = new address[][](1);
        tokens[0] = new address[](2);
        tokens[0][0] = address(weth);
        tokens[0][1] = address(op);
        rootVoter.claimFees(feesVotingRewards, tokens, tokenId);

        // Process pending Claim on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(weth.balanceOf(user), expectedBalanceWETH);
        assertEq(op.balanceOf(user), expectedBalanceOP);
        vm.stopPrank();

        selectForkAndSyncTimestamp({forkId: activeFork});
    }

    /// @dev Helper to keep timestamps synced after fork selections
    function selectForkAndSyncTimestamp(uint256 forkId) internal {
        vm.selectFork({forkId: forkId});
        skipToTimestamp({newTimestamp: warpTs});
    }

    /// @dev Helper to update timestamp and block number
    function skipToTimestamp(uint256 newTimestamp) internal returns (uint256 timeElapsed) {
        warpTs = newTimestamp;
        timeElapsed = newTimestamp - block.timestamp;
        vm.warp({newTimestamp: newTimestamp});
        vm.roll({newHeight: block.number + timeElapsed / 2});
    }

    function testFork_GaugeFlow() public {
        // create staked LPer
        vm.startPrank(users.alice);
        deal(address(weth), users.alice, TOKEN_1 * 1_000);
        weth.approve(address(e2eNftCallee), TOKEN_1 * 1_000);
        deal(address(op), users.alice, TOKEN_1 * 1_000_000);
        op.approve(address(e2eNftCallee), TOKEN_1 * 1_000_000);
        uint256 tokenIdAlice = e2eNftCallee.mintNewFullRangePositionForUserWith60TickSpacing(
            TOKEN_1 * 1_000, TOKEN_1 * 1_000_000, users.alice
        );
        nft.approve(address(leafGauge), tokenIdAlice);
        leafGauge.deposit(tokenIdAlice);
        vm.stopPrank();

        //check balances went to staked position
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(op.balanceOf(users.alice), 0);
        assertEq(leafXVelo.balanceOf(users.alice), 0);

        checkEmissions(users.alice, tokenIdAlice, 0);

        //going to epoch 1
        // alice is staked lper
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1});

        selectForkAndSyncTimestamp({forkId: rootId});

        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        //create unstaked LPer
        vm.startPrank(users.bob);
        deal(address(weth), users.bob, TOKEN_1 * 1_000);
        weth.approve(address(e2eNftCallee), TOKEN_1 * 1_000);
        deal(address(op), users.bob, TOKEN_1 * 1_000_000);
        op.approve(address(e2eNftCallee), TOKEN_1 * 1_000_000);
        uint256 tokenIdBob = e2eNftCallee.mintNewFullRangePositionForUserWith60TickSpacing(
            TOKEN_1 * 1_000, TOKEN_1 * 1_000_000, users.bob
        );
        vm.stopPrank();

        //check balances went to unstaked position
        assertEq(weth.balanceOf(users.bob), 0);
        assertEq(op.balanceOf(users.bob), 0);

        checkEmissions(users.alice, tokenIdAlice, 0);

        //going to epoch 2
        // alice is staked lper
        // bob is unstaked lper
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1});

        selectForkAndSyncTimestamp({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 999999999999999999);

        //check fees accrued by bob - unstaked lper
        vm.startPrank(users.bob);
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenIdBob,
                recipient: users.bob,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        //bob has collected rewards from his unstaked position
        assertEq(weth.balanceOf(users.bob), 148499999999999999);
        assertEq(op.balanceOf(users.bob), 14849999999999999999);

        //bob stakes
        nft.approve(address(leafGauge), tokenIdBob);
        leafGauge.deposit(tokenIdBob);
        vm.stopPrank();

        //emission = TOKEN_1 ~ 999999999999999999
        checkEmissions(users.alice, tokenIdAlice, 999999999999999999);
        checkEmissions(users.bob, tokenIdBob, 0);

        //going to epoch 3
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1});

        selectForkAndSyncTimestamp({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        //emission = TOKEN_1 ~ 999999999999999999
        // emission for each user = TOKEN_1 / 2 ~ 499999999999999999
        checkEmissions(users.alice, tokenIdAlice, 1499999999999999998);
        checkEmissions(users.bob, tokenIdBob, 499999999999999999);

        //going to epoch 4
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1});

        selectForkAndSyncTimestamp({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 1999999999999999997);
        checkEmissions(users.bob, tokenIdBob, 999999999999999998);

        // Alice creates veNFT to vote
        selectForkAndSyncTimestamp({forkId: rootId});
        deal(address(rewardToken), users.alice, TOKEN_1 * 1_000);
        vm.startPrank(users.alice);
        rewardToken.approve(address(escrow), TOKEN_1 * 1_000);
        uint256 tokenIdVeAlice = escrow.createLock(TOKEN_1 * 1_000, 365 days * 4);
        vm.stopPrank();

        // Skip distribute window
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1});
        checkFees(users.alice, tokenIdVeAlice, 0, 0);

        selectForkAndSyncTimestamp({forkId: leafId});
        //going to epoch 5
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1});

        selectForkAndSyncTimestamp({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 2499999999999999996);
        checkEmissions(users.bob, tokenIdBob, 1499999999999999997);
        checkFees(users.alice, tokenIdVeAlice, 0, 0);

        selectForkAndSyncTimestamp({forkId: rootId});
        // Alice votes
        vm.startPrank(users.alice);
        address[] memory pools = new address[](1);
        pools[0] = address(rootPool);
        uint256[] memory votes = new uint256[](1);
        votes[0] = 100;
        rootVoter.vote(tokenIdVeAlice, pools, votes);
        vm.stopPrank();

        // Process votes on Leaf Chain
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        //going to epoch 6
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1});

        selectForkAndSyncTimestamp({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 2999999999999999995);
        checkEmissions(users.bob, tokenIdBob, 1999999999999999996);

        // Skip distribute window
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1});
        checkFees(users.alice, tokenIdVeAlice, 300000000000000001, 30000000000000000001);

        //Bob creates veNFT to vote
        selectForkAndSyncTimestamp({forkId: rootId});
        deal(address(rewardToken), users.bob, TOKEN_1 * 1_000);
        vm.startPrank(users.bob);
        rewardToken.approve(address(escrow), TOKEN_1 * 1_000);
        uint256 tokenIdVeBob = escrow.createLock(TOKEN_1 * 1_000, 365 days * 4);
        vm.stopPrank();

        //going to epoch 7
        selectForkAndSyncTimestamp({forkId: leafId});
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1});

        selectForkAndSyncTimestamp({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 3499999999999999994);
        checkEmissions(users.bob, tokenIdBob, 2499999999999999995);
        checkFees(users.alice, tokenIdVeAlice, 600000000000000002, 60000000000000000002);
        checkFees(users.bob, tokenIdVeBob, 148499999999999999, 14849999999999999999);

        // Bob votes
        selectForkAndSyncTimestamp({forkId: rootId});
        vm.prank(users.bob);
        rootVoter.vote(tokenIdVeBob, pools, votes);

        // Process votes on Leaf Chain
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 3499999999999999994);
        checkEmissions(users.bob, tokenIdBob, 2499999999999999995);

        //large token holder stakes
        vm.startPrank(largeTokenHolder);
        deal(address(weth), largeTokenHolder, TOKEN_1 * 10_000);
        weth.approve(address(e2eNftCallee), TOKEN_1 * 10_000);
        deal(address(op), largeTokenHolder, TOKEN_1 * 100_000_000);
        op.approve(address(e2eNftCallee), TOKEN_1 * 100_000_000);
        uint256 tokenIdLarge = e2eNftCallee.mintNewFullRangePositionForUserWith60TickSpacing(
            TOKEN_1 * 10_000, TOKEN_1 * 100_000_000, largeTokenHolder
        );
        nft.approve(address(leafGauge), tokenIdLarge);
        leafGauge.deposit(tokenIdLarge);
        vm.stopPrank();

        //going to epoch 8
        doSomeSwaps();
        selectForkAndSyncTimestamp({forkId: rootId});
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1});

        vm.prank(address(rootVoter));
        rewardToken.approve(address(rootGauge), 0);
        minter.updatePeriod();

        selectForkAndSyncTimestamp({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(rootGauge)), 1000000000000000011);

        selectForkAndSyncTimestamp({forkId: rootId});
        address[] memory gauges = new address[](1);
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);
        // Process distribute on Leaf Chain
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipToTimestamp({newTimestamp: warpTs + 1});
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 16088483549169599701);

        checkEmissions(users.alice, tokenIdAlice, 3507737289041773005);
        checkEmissions(users.bob, tokenIdBob, 2507737289041773006);
        checkEmissions(largeTokenHolder, tokenIdLarge, 984550519236225249);
        checkFees(users.alice, tokenIdVeAlice, 750000000000000002, 75000000000000000002);
        checkFees(users.bob, tokenIdVeBob, 298499999999999999, 29849999999999999999);

        //going to epoch 9
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1});
        selectForkAndSyncTimestamp({forkId: rootId});
        minter.updatePeriod();

        selectForkAndSyncTimestamp({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 15088458451849828430);

        selectForkAndSyncTimestamp({forkId: rootId});
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);
        // Process distribute on Leaf Chain
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafXVelo.balanceOf(address(leafGauge)), 30026057165527731071);
        skipToTimestamp({newTimestamp: warpTs + 1});

        //large token holder creates lock
        selectForkAndSyncTimestamp({forkId: rootId});
        deal(address(rewardToken), largeTokenHolder, TOKEN_1 * 100_000_000);
        vm.startPrank(largeTokenHolder);
        rewardToken.approve(address(escrow), TOKEN_1 * 100_000_000);
        uint256 tokenIdVeLarge = escrow.createLock(TOKEN_1 * 100_000_000, 365 days * 4);
        vm.stopPrank();

        //large token holder votes
        vm.prank(largeTokenHolder);
        rootVoter.vote(tokenIdVeLarge, pools, votes);

        // Process votes on Leaf Chain
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        //going to epoch 10
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1});

        selectForkAndSyncTimestamp({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 30026057165527731071);

        selectForkAndSyncTimestamp({forkId: rootId});
        minter.updatePeriod();
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);

        // Process distribute on Leaf Chain
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 72051244542878753336727);
        skipToTimestamp({newTimestamp: warpTs + 1});

        checkEmissions(users.alice, tokenIdAlice, 3740978614444447120);
        checkEmissions(users.bob, tokenIdBob, 2740978614444447121);
        checkEmissions(largeTokenHolder, tokenIdLarge, 30663921005817698369);
        checkFees(users.alice, tokenIdVeAlice, 900002985517110672, 90000298551711067029);
        checkFees(users.bob, tokenIdVeBob, 448502985517110669, 44850298551711067026);
        checkFees(largeTokenHolder, tokenIdVeLarge, 299994028965778659, 29999402896577865944);

        //going to epoch 11
        doSomeSwaps();
        skipToTimestamp({newTimestamp: VelodromeTimeLibrary.epochNext(block.timestamp) + 1 hours + 1});

        selectForkAndSyncTimestamp({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 72021098689741366515377);

        selectForkAndSyncTimestamp({forkId: rootId});
        minter.updatePeriod();
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);

        // Process distribute on Leaf Chain
        selectForkAndSyncTimestamp({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 143322104990597459864976);
        skipToTimestamp({newTimestamp: warpTs + 1});

        checkEmissions(users.alice, tokenIdAlice, 560975968805396090027);
        checkEmissions(users.bob, tokenIdBob, 559975968805396090028);
        checkEmissions(largeTokenHolder, tokenIdLarge, 70937411228377421427306);
        checkFees(users.alice, tokenIdVeAlice, 900005971034221342, 90000597103422134056);
        checkFees(users.bob, tokenIdVeBob, 448505971034221339, 44850597103422134053);
        checkFees(largeTokenHolder, tokenIdVeLarge, 599988057931557318, 59998805793155731888);
    }
}
