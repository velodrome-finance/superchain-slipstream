// pragma solidity ^0.7.6;
// pragma abicoder v2;

// import "../BaseForkFixture.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import "../../../contracts/periphery/libraries/TransferHelper.sol";
// import "../../../contracts/periphery/interfaces/ISwapRouter.sol";
// import {SwapRouter} from "../../../contracts/periphery/SwapRouter.sol";
// import {IReward} from "../../../contracts/gauge/interfaces/IReward.sol";

// contract GaugeFlowTest is BaseForkFixture {
//     CLPool public pool;
//     ISwapRouter public swapRouter;
//     CLLeafGauge public gauge;
//     address public feesVotingReward;
//     uint256 EMISSION = TOKEN_1;
//     address largeTokenHolder = vm.addr(0x123454321);

//     function setUp() public override {
//         super.setUp();

//         pool = CLPool(
//             poolFactory.createPool({
//                 tokenA: address(weth),
//                 tokenB: address(op),
//                 tickSpacing: TICK_SPACING_60,
//                 sqrtPriceX96: encodePriceSqrt(1, 1)
//             })
//         );

//         swapRouter = new SwapRouter(address(poolFactory), address(weth));

//         vm.prank(users.feeManager);
//         customUnstakedFeeModule.setCustomFee(address(pool), 10_000);

//         // gauge = CLLeafGauge(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));
//         //
//         // feesVotingReward = gauge.feesVotingReward();
//         //
//         skipToNextEpoch(0);

//         // Early deposit of rewards on voter
//         // will be used to send to the gauge each epoch
//         deal(address(rewardToken), address(voter), EMISSION * 100);
//         vm.prank(address(voter));
//         // rewardToken.approve(address(gauge), EMISSION * 100);
//     }

//     //swaps a certain amount of token0 for token1 - only intended for testing purposes
//     function doSwap(uint256 _amount, address user, bool token0In) internal returns (uint256 amountOut) {
//         TransferHelper.safeApprove(token0In ? pool.token0() : pool.token1(), address(swapRouter), _amount);
//         amountOut = swapRouter.exactInputSingle(
//             ISwapRouter.ExactInputSingleParams({
//                 tokenIn: token0In ? pool.token0() : pool.token1(),
//                 tokenOut: token0In ? pool.token1() : pool.token0(),
//                 tickSpacing: pool.tickSpacing(),
//                 recipient: user,
//                 deadline: block.timestamp,
//                 amountIn: _amount,
//                 amountOutMinimum: 0,
//                 sqrtPriceLimitX96: 0
//             })
//         );
//     }

//     function doSomeSwaps() internal {
//         vm.startPrank(users.charlie);
//         deal(address(weth), users.charlie, TOKEN_1 * 100);
//         doSwap(TOKEN_1 * 100, users.charlie, true);

//         skip(1 hours);

//         deal(address(op), users.charlie, TOKEN_1 * 10_000);
//         doSwap(TOKEN_1 * 10000, users.charlie, false);
//         vm.stopPrank();

//         skip(1 hours);
//     }

//     function checkEmissions(address user, uint256 tokenId, uint256 expectedBalance) internal {
//         vm.startPrank(user);
//         gauge.getReward(tokenId);
//         assertEq(rewardToken.balanceOf(user), expectedBalance);
//         vm.stopPrank();
//     }

//     function checkFees(address user, uint256 tokenId, uint256 expectedBalanceWETH, uint256 expectedBalanceOP)
//         internal
//     {
//         vm.startPrank(user);
//         //claim fees rewards
//         address[] memory feesVotingRewards = new address[](1);
//         feesVotingRewards[0] = feesVotingReward;
//         address[][] memory tokens = new address[][](1);
//         tokens[0] = new address[](2);
//         tokens[0][0] = address(weth);
//         tokens[0][1] = address(op);
//         voter.claimFees(feesVotingRewards, tokens, tokenId);

//         assertEq(weth.balanceOf(user), expectedBalanceWETH);
//         assertEq(op.balanceOf(user), expectedBalanceOP);
//         vm.stopPrank();
//     }

//     function testFork_GaugeFlow() public {
//         //create staked LPer
//         // vm.startPrank(users.alice);
//         // deal(address(weth), users.alice, TOKEN_1 * 1_000);
//         // weth.approve(address(nftCallee), TOKEN_1 * 1_000);
//         // deal(address(op), users.alice, TOKEN_1 * 1_000_000);
//         // op.approve(address(nftCallee), TOKEN_1 * 1_000_000);
//         // uint256 tokenIdAlice = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(
//         //     TOKEN_1 * 1_000, TOKEN_1 * 1_000_000, users.alice
//         // );
//         // nft.approve(address(gauge), tokenIdAlice);
//         // gauge.deposit(tokenIdAlice);
//         // vm.stopPrank();
//         //
//         // //check balances went to staked position
//         // assertEq(weth.balanceOf(users.alice), 0);
//         // assertEq(op.balanceOf(users.alice), 0);
//         // assertEq(rewardToken.balanceOf(users.alice), 0);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 0);
//         //
//         // //going to epoch 1
//         // // alice is staked lper
//         // skipToNextEpoch(1);
//         // vm.prank(address(voter));
//         // gauge.notifyRewardAmount(EMISSION);
//         //
//         // //create unstaked LPer
//         // vm.startPrank(users.bob);
//         // deal(address(weth), users.bob, TOKEN_1 * 1_000);
//         // weth.approve(address(nftCallee), TOKEN_1 * 1_000);
//         // deal(address(op), users.bob, TOKEN_1 * 1_000_000);
//         // op.approve(address(nftCallee), TOKEN_1 * 1_000_000);
//         // uint256 tokenIdBob =
//         //     nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 1_000, TOKEN_1 * 1_000_000, users.bob);
//         // vm.stopPrank();
//         //
//         // //check balances went to unstaked position
//         // assertEq(weth.balanceOf(users.bob), 0);
//         // assertEq(op.balanceOf(users.bob), 0);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 0);
//         //
//         // //going to epoch 2
//         // // alice is staked lper
//         // // bob is unstaked lper
//         // doSomeSwaps();
//         // skipToNextEpoch(1);
//         // vm.prank(address(voter));
//         // gauge.notifyRewardAmount(EMISSION);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 999999999999999999);
//         //
//         // //check fees accrued by bob - unstaked lper
//         // vm.startPrank(users.bob);
//         // nft.collect(
//         //     INonfungiblePositionManager.CollectParams({
//         //         tokenId: tokenIdBob,
//         //         recipient: users.bob,
//         //         amount0Max: type(uint128).max,
//         //         amount1Max: type(uint128).max
//         //     })
//         // );
//         // //bob has collected rewards from his unstaked position
//         // assertEq(weth.balanceOf(users.bob), 148499999999999999);
//         // assertEq(op.balanceOf(users.bob), 14849999999999999999);
//         //
//         // //bob stakes
//         // nft.approve(address(gauge), tokenIdBob);
//         // gauge.deposit(tokenIdBob);
//         // vm.stopPrank();
//         //
//         // //emission = TOKEN_1 ~ 999999999999999999
//         // checkEmissions(users.alice, tokenIdAlice, 999999999999999999);
//         // checkEmissions(users.bob, tokenIdBob, 0);
//         //
//         // //going to epoch 3
//         // doSomeSwaps();
//         // skipToNextEpoch(1);
//         // vm.prank(address(voter));
//         // gauge.notifyRewardAmount(EMISSION);
//         //
//         // //emission = TOKEN_1 ~ 999999999999999999
//         // // emission for each user = TOKEN_1 / 2 ~ 499999999999999999
//         // checkEmissions(users.alice, tokenIdAlice, 1499999999999999998);
//         // checkEmissions(users.bob, tokenIdBob, 499999999999999999);
//         //
//         // //going to epoch 4
//         // doSomeSwaps();
//         // skipToNextEpoch(1);
//         // vm.prank(address(voter));
//         // gauge.notifyRewardAmount(EMISSION);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 1999999999999999997);
//         // checkEmissions(users.bob, tokenIdBob, 999999999999999998);
//         //
//         // // Alice creates veNFT to vote
//         // deal(address(rewardToken), users.alice, TOKEN_1 * 1_000);
//         // vm.startPrank(users.alice);
//         // rewardToken.approve(address(escrow), TOKEN_1 * 1_000);
//         // uint256 tokenIdVeAlice = escrow.createLock(TOKEN_1 * 1_000, 365 days * 4);
//         // vm.stopPrank();
//         //
//         // checkFees(users.alice, tokenIdVeAlice, 0, 0);
//         //
//         // //going to epoch 5
//         // doSomeSwaps();
//         // skipToNextEpoch(1 hours + 1);
//         // vm.prank(address(voter));
//         // gauge.notifyRewardAmount(EMISSION);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 499999999999999999);
//         // checkEmissions(users.bob, tokenIdBob, 1499999999999999997);
//         // checkFees(users.alice, tokenIdVeAlice, 0, 0);
//         //
//         // // Alice votes
//         // vm.startPrank(users.alice);
//         // address[] memory pools = new address[](1);
//         // pools[0] = address(pool);
//         // uint256[] memory votes = new uint256[](1);
//         // votes[0] = 100;
//         // voter.vote(tokenIdVeAlice, pools, votes);
//         // vm.stopPrank();
//         //
//         // //going to epoch 6
//         // doSomeSwaps();
//         // skipToNextEpoch(1);
//         // vm.prank(address(voter));
//         // gauge.notifyRewardAmount(EMISSION);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 999999999999999998);
//         // checkEmissions(users.bob, tokenIdBob, 1999999999999999996);
//         // checkFees(users.alice, tokenIdVeAlice, 300000000000000001, 30000000000000000001);
//         //
//         // //Bob creates veNFT to vote
//         // deal(address(rewardToken), users.bob, TOKEN_1 * 1_000);
//         // vm.startPrank(users.bob);
//         // rewardToken.approve(address(escrow), TOKEN_1 * 1_000);
//         // uint256 tokenIdVeBob = escrow.createLock(TOKEN_1 * 1_000, 365 days * 4);
//         // vm.stopPrank();
//         //
//         // //going to epoch 7
//         // doSomeSwaps();
//         // skipToNextEpoch(1 hours + 1);
//         // vm.prank(address(voter));
//         // gauge.notifyRewardAmount(EMISSION);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 1499999999999999997);
//         // checkEmissions(users.bob, tokenIdBob, 499999999999999999);
//         // checkFees(users.alice, tokenIdVeAlice, 600000000000000002, 60000000000000000002);
//         // checkFees(users.bob, tokenIdVeBob, 148499999999999999, 14849999999999999999);
//         //
//         // // Bob votes
//         // vm.startPrank(users.bob);
//         // voter.vote(tokenIdVeBob, pools, votes);
//         // vm.stopPrank();
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 1499999999999999997);
//         // checkEmissions(users.bob, tokenIdBob, 499999999999999999);
//         // checkFees(users.alice, tokenIdVeAlice, 600000000000000002, 60000000000000000002);
//         // checkFees(users.bob, tokenIdVeBob, 148499999999999999, 14849999999999999999);
//         //
//         // //large token holder stakes
//         // vm.startPrank(largeTokenHolder);
//         // deal(address(weth), largeTokenHolder, TOKEN_1 * 10_000);
//         // weth.approve(address(nftCallee), TOKEN_1 * 10_000);
//         // deal(address(op), largeTokenHolder, TOKEN_1 * 100_000_000);
//         // op.approve(address(nftCallee), TOKEN_1 * 100_000_000);
//         // uint256 tokenIdLarge = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(
//         //     TOKEN_1 * 10_000, TOKEN_1 * 100_000_000, largeTokenHolder
//         // );
//         // nft.approve(address(gauge), tokenIdLarge);
//         // gauge.deposit(tokenIdLarge);
//         // vm.stopPrank();
//         //
//         // //going to epoch 8
//         // doSomeSwaps();
//         // skipToNextEpoch(1 hours + 1);
//         // vm.prank(address(voter));
//         // rewardToken.approve(address(gauge), 0);
//         // minter.updatePeriod();
//         //
//         // assertEq(rewardToken.balanceOf(address(gauge)), 1000000000000000011);
//         // address[] memory gauges = new address[](1);
//         // gauges[0] = address(gauge);
//         // voter.distribute(gauges);
//         // skip(1);
//         // assertEq(rewardToken.balanceOf(address(gauge)), 35810626802173324795);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 1507737542854725490);
//         // checkEmissions(users.bob, tokenIdBob, 507737542854725492);
//         // checkEmissions(largeTokenHolder, tokenIdLarge, 984582816294381642);
//         // checkFees(users.alice, tokenIdVeAlice, 750000000000000002, 75000000000000000002);
//         // checkFees(users.bob, tokenIdVeBob, 298499999999999999, 29849999999999999999);
//         //
//         // //going to epoch 9
//         // doSomeSwaps();
//         // skipToNextEpoch(1 hours + 1);
//         // minter.updatePeriod();
//         // assertEq(rewardToken.balanceOf(address(gauge)), 34810568900169492167);
//         // gauges[0] = address(gauge);
//         // voter.distribute(gauges);
//         // assertEq(rewardToken.balanceOf(address(gauge)), 69273089434321083902);
//         // skip(1);
//         //
//         // //large token holder creates lock
//         // deal(address(rewardToken), largeTokenHolder, TOKEN_1 * 100_000_000);
//         // vm.startPrank(largeTokenHolder);
//         // rewardToken.approve(address(escrow), TOKEN_1 * 100_000_000);
//         // uint256 tokenIdVeLarge = escrow.createLock(TOKEN_1 * 100_000_000, 365 days * 4);
//         // vm.stopPrank();
//         //
//         // //large token holder votes
//         // vm.startPrank(largeTokenHolder);
//         // voter.vote(tokenIdVeLarge, pools, votes);
//         // vm.stopPrank();
//         //
//         // //going to epoch 10
//         // doSomeSwaps();
//         // skipToNextEpoch(1 hours + 1);
//         // minter.updatePeriod();
//         // assertEq(rewardToken.balanceOf(address(gauge)), 69273089434321083902);
//         // gauges[0] = address(gauge);
//         // voter.distribute(gauges);
//         // assertEq(rewardToken.balanceOf(address(gauge)), 1490780679105507604474671);
//         // skip(1);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 2062894629148314146);
//         // checkEmissions(users.bob, tokenIdBob, 1062894629148314148);
//         // checkEmissions(largeTokenHolder, tokenIdLarge, 70642339276338177846);
//         // checkFees(users.alice, tokenIdVeAlice, 900002985517110672, 90000298551711067029);
//         // checkFees(users.bob, tokenIdVeBob, 448502985517110669, 44850298551711067026);
//         // checkFees(largeTokenHolder, tokenIdVeLarge, 299994028965778659, 29999402896577865944);
//         //
//         // //going to epoch 11
//         // doSomeSwaps();
//         // skipToNextEpoch(1 hours + 1);
//         // minter.updatePeriod();
//         // assertEq(rewardToken.balanceOf(address(gauge)), 1490708926452058679119513);
//         // gauges[0] = address(gauge);
//         // voter.distribute(gauges);
//         // assertEq(rewardToken.balanceOf(address(gauge)), 2966513218407971276547198);
//         // skip(1);
//         //
//         // checkEmissions(users.alice, tokenIdAlice, 11535838262143747842625);
//         // checkEmissions(users.bob, tokenIdBob, 11534838262143747842627);
//         // checkEmissions(largeTokenHolder, tokenIdLarge, 1467714472824680276469020);
//         // checkFees(users.alice, tokenIdVeAlice, 900005971034221342, 90000597103422134056);
//         // checkFees(users.bob, tokenIdVeBob, 448505971034221339, 44850597103422134053);
//         // checkFees(largeTokenHolder, tokenIdVeLarge, 599988057931557318, 59998805793155731888);
//     }
// }
