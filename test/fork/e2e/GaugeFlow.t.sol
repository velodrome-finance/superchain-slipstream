pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../BaseForkFixture.sol";
import "../../../contracts/periphery/libraries/TransferHelper.sol";
import {ISwapRouter, SwapRouter} from "../../../contracts/periphery/SwapRouter.sol";

contract GaugeFlowTest is BaseForkFixture {
    ISwapRouter public swapRouter;
    address public feesVotingReward;
    uint256 EMISSION = TOKEN_1;
    address largeTokenHolder = vm.addr(0x123454321);

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
            CLPool(poolFactory.getPool({tokenA: address(weth), tokenB: address(op), tickSpacing: TICK_SPACING_60}));
        leafGauge = LeafCLGauge(leafVoter.gauges(address(leafPool)));

        swapRouter = new SwapRouter(address(poolFactory), address(weth));

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(leafPool), 10_000);

        skipToNextEpoch(0);

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

        skipTime(1 hours);

        deal(address(op), users.charlie, TOKEN_1 * 10_000);
        doSwap(TOKEN_1 * 10000, users.charlie, false);
        vm.stopPrank();

        skipTime(1 hours);
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

        vm.selectFork({forkId: rootId});
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
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(weth.balanceOf(user), expectedBalanceWETH);
        assertEq(op.balanceOf(user), expectedBalanceOP);
        vm.stopPrank();

        vm.selectFork({forkId: activeFork});
    }

    /// @dev Helper utility to forward time to next week on all chains
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 _offset) public override {
        uint256 timeToNextEpoch = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        skipTime(timeToNextEpoch + _offset);
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
        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});

        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
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
        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
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
        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        //emission = TOKEN_1 ~ 999999999999999999
        // emission for each user = TOKEN_1 / 2 ~ 499999999999999999
        checkEmissions(users.alice, tokenIdAlice, 1499999999999999998);
        checkEmissions(users.bob, tokenIdBob, 499999999999999999);

        //going to epoch 4
        doSomeSwaps();
        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 1999999999999999997);
        checkEmissions(users.bob, tokenIdBob, 999999999999999998);

        // Alice creates veNFT to vote
        vm.selectFork({forkId: rootId});
        deal(address(rewardToken), users.alice, TOKEN_1 * 1_000);
        vm.startPrank(users.alice);
        rewardToken.approve(address(escrow), TOKEN_1 * 1_000);
        uint256 tokenIdVeAlice = escrow.createLock(TOKEN_1 * 1_000, 365 days * 4);
        vm.stopPrank();

        checkFees(users.alice, tokenIdVeAlice, 0, 0);

        vm.selectFork({forkId: leafId});
        //going to epoch 5
        doSomeSwaps();
        skipToNextEpoch(1 hours + 1);

        vm.selectFork({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 2499999999999999996);
        checkEmissions(users.bob, tokenIdBob, 1499999999999999997);
        checkFees(users.alice, tokenIdVeAlice, 0, 0);

        vm.selectFork({forkId: rootId});
        // Alice votes
        vm.startPrank(users.alice);
        address[] memory pools = new address[](1);
        pools[0] = address(rootPool);
        uint256[] memory votes = new uint256[](1);
        votes[0] = 100;
        rootVoter.vote(tokenIdVeAlice, pools, votes);
        vm.stopPrank();

        // Process votes on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        //going to epoch 6
        doSomeSwaps();
        skipToNextEpoch(1);

        vm.selectFork({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 2999999999999999995);
        checkEmissions(users.bob, tokenIdBob, 1999999999999999996);
        checkFees(users.alice, tokenIdVeAlice, 300000000000000001, 30000000000000000001);

        //Bob creates veNFT to vote
        vm.selectFork({forkId: rootId});
        deal(address(rewardToken), users.bob, TOKEN_1 * 1_000);
        vm.startPrank(users.bob);
        rewardToken.approve(address(escrow), TOKEN_1 * 1_000);
        uint256 tokenIdVeBob = escrow.createLock(TOKEN_1 * 1_000, 365 days * 4);
        vm.stopPrank();

        //going to epoch 7
        vm.selectFork({forkId: leafId});
        doSomeSwaps();
        skipToNextEpoch(1 hours + 1);

        vm.selectFork({forkId: rootId});
        vm.prank(address(rootVoter));
        rootGauge.notifyRewardAmount(EMISSION);

        // Process pending notify on Leaf
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 3499999999999999994);
        checkEmissions(users.bob, tokenIdBob, 2499999999999999995);
        checkFees(users.alice, tokenIdVeAlice, 600000000000000002, 60000000000000000002);
        checkFees(users.bob, tokenIdVeBob, 148499999999999999, 14849999999999999999);

        // Bob votes
        vm.selectFork({forkId: rootId});
        vm.prank(users.bob);
        rootVoter.vote(tokenIdVeBob, pools, votes);

        // Process votes on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        checkEmissions(users.alice, tokenIdAlice, 3499999999999999994);
        checkEmissions(users.bob, tokenIdBob, 2499999999999999995);
        checkFees(users.alice, tokenIdVeAlice, 600000000000000002, 60000000000000000002);
        checkFees(users.bob, tokenIdVeBob, 148499999999999999, 14849999999999999999);

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
        vm.selectFork({forkId: rootId});
        skipToNextEpoch(1 hours + 1);
        vm.prank(address(rootVoter));
        rewardToken.approve(address(rootGauge), 0);
        minter.updatePeriod();

        vm.selectFork({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(rootGauge)), 1000000000000000011);

        vm.selectFork({forkId: rootId});
        address[] memory gauges = new address[](1);
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);
        // Process distribute on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipTime(1);
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 16547094994568128102);

        checkEmissions(users.alice, tokenIdAlice, 3507737294943845793);
        checkEmissions(users.bob, tokenIdBob, 2507737294943845794);
        checkEmissions(largeTokenHolder, tokenIdLarge, 984551270260104003);
        checkFees(users.alice, tokenIdVeAlice, 750000000000000002, 75000000000000000002);
        checkFees(users.bob, tokenIdVeBob, 298499999999999999, 29849999999999999999);

        //going to epoch 9
        doSomeSwaps();
        skipToNextEpoch(1 hours + 1);
        vm.selectFork({forkId: rootId});
        minter.updatePeriod();

        vm.selectFork({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 15547069134420332501);

        vm.selectFork({forkId: rootId});
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);
        // Process distribute on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        assertEq(leafXVelo.balanceOf(address(leafGauge)), 30938693179042778160);
        skipTime(1);

        //large token holder creates lock
        vm.selectFork({forkId: rootId});
        deal(address(rewardToken), largeTokenHolder, TOKEN_1 * 100_000_000);
        vm.startPrank(largeTokenHolder);
        rewardToken.approve(address(escrow), TOKEN_1 * 100_000_000);
        uint256 tokenIdVeLarge = escrow.createLock(TOKEN_1 * 100_000_000, 365 days * 4);
        vm.stopPrank();

        //large token holder votes
        vm.prank(largeTokenHolder);
        rootVoter.vote(tokenIdVeLarge, pools, votes);

        // Process votes on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        //going to epoch 10
        doSomeSwaps();
        skipToNextEpoch(1 hours + 1);

        vm.selectFork({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 30938693179042778160);

        vm.selectFork({forkId: rootId});
        minter.updatePeriod();
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);

        // Process distribute on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 74256737633210131757594);
        skipTime(1);

        checkEmissions(users.alice, tokenIdAlice, 3748068143474401712);
        checkEmissions(users.bob, tokenIdBob, 2748068143474401713);
        checkEmissions(largeTokenHolder, tokenIdLarge, 31566045697023832639);
        checkFees(users.alice, tokenIdVeAlice, 900002985517110672, 90000298551711067029);
        checkFees(users.bob, tokenIdVeBob, 448502985517110669, 44850298551711067026);
        checkFees(largeTokenHolder, tokenIdVeLarge, 299994028965778659, 29999402896577865944);

        //going to epoch 11
        doSomeSwaps();
        skipToNextEpoch(1 hours + 1);

        vm.selectFork({forkId: leafId});
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 74225675477086306917120);

        vm.selectFork({forkId: rootId});
        minter.updatePeriod();
        gauges[0] = address(rootGauge);
        rootVoter.distribute(gauges);

        // Process distribute on Leaf Chain
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), 147709216427717085006760);
        skipTime(1);

        checkEmissions(users.alice, tokenIdAlice, 578040106155418805352);
        checkEmissions(users.bob, tokenIdBob, 577040106155418805353);
        checkEmissions(largeTokenHolder, tokenIdLarge, 73108779675074776184168);
        checkFees(users.alice, tokenIdVeAlice, 900005971034221342, 90000597103422134056);
        checkFees(users.bob, tokenIdVeBob, 448505971034221339, 44850597103422134053);
        checkFees(largeTokenHolder, tokenIdVeLarge, 599988057931557318, 59998805793155731888);
    }
}
