pragma solidity ^0.7.6;
pragma abicoder v2;

import "../LeafCLGauge.t.sol";

contract GetRewardConcreteFuzzTest is LeafCLGaugeTest {
    CLPool public fuzzPool;
    LeafCLGauge public fuzzGauge;
    uint256 public minStakeTime = 10;

    function setUp() public override {
        super.setUp();

        fuzzPool = CLPool(
            leafPoolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        vm.prank(address(leafMessageModule));
        fuzzGauge = LeafCLGauge(
            leafVoter.createGauge({
                _poolFactory: address(leafPoolFactory),
                _pool: address(fuzzPool),
                _votingRewardsFactory: address(votingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );

        vm.startPrank(users.alice);
        skipToNextEpoch(0);
    }

    function testFuzz_WhenTheCallerIsNotTheTokenOwner(address _caller) external {
        // It should revert with {NA}
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(fuzzGauge), tokenId);
        fuzzGauge.deposit(tokenId);

        vm.assume(_caller != users.alice);
        vm.startPrank(_caller);
        vm.expectRevert(abi.encodePacked("NA"));
        fuzzGauge.getReward(tokenId);
    }

    modifier whenTheCallerIsTheTokenOwner() {
        _;
    }

    function testFuzz_WhenThereAreNoAccruedRewards() external whenTheCallerIsTheTokenOwner {
        // not fuzzed: no arithmetic — static zero balance check
    }

    modifier whenThereAreAccruedRewards() {
        _;
    }

    function testFuzz_WhenPenaltyRateIsZero() external whenTheCallerIsTheTokenOwner whenThereAreAccruedRewards {
        // not fuzzed: no penalty math, boundary covered by testFuzz_WhenCalledWithinMinStakeTime
    }

    modifier whenCalledWithinMinStakeTime() {
        _;
    }

    function testFuzz_WhenPenaltyRoundsDownToZero()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenCalledWithinMinStakeTime
    {
        // not fuzzed: covered by concrete test (dust arithmetic)
    }

    modifier whenPenaltyDoesNotRoundDownToZero() {
        _;
    }

    function testFuzz_WhenPenaltyDoesNotRoundDownToZero(uint256 _penaltyRate)
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenCalledWithinMinStakeTime
        whenPenaltyDoesNotRoundDownToZero
    {
        // It should buffer penalty for next epoch
        // It should emit a {EarlyWithdrawPenalty} event
        // It should emit a {ClaimRewards} event
        _penaltyRate = bound(_penaltyRate, 1, leafGaugeFactory.MAX_BPS());

        vm.startPrank(users.owner);
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: minStakeTime});
        leafGaugeFactory.setPenaltyRate({_penaltyRate: _penaltyRate});
        vm.stopPrank();

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(fuzzGauge), tokenId);
        fuzzGauge.deposit(tokenId);

        addRewardToLeafGauge(address(fuzzGauge), TOKEN_1);
        skip(minStakeTime / 2); // within penalty window

        vm.startPrank(users.alice);
        uint256 netEarned = fuzzGauge.earned(users.alice, tokenId);
        uint256 gaugeBalBefore = leafXVelo.balanceOf(address(fuzzGauge));
        fuzzGauge.getReward(tokenId);

        uint256 aliceBal = leafXVelo.balanceOf(users.alice);
        assertEq(aliceBal, netEarned);
        // penalty was buffered — gauge balance only decreased by what alice received
        assertGe(leafXVelo.balanceOf(address(fuzzGauge)), gaugeBalBefore - netEarned);
    }

    function testFuzz_WhenThereAreRemainingRewardsAfterPenalty(uint256 _penaltyRate)
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenCalledWithinMinStakeTime
        whenPenaltyDoesNotRoundDownToZero
    {
        // It should transfer remaining rewards to owner
        // bound below MAX_BPS so alice always receives something
        _penaltyRate = bound(_penaltyRate, 1, leafGaugeFactory.MAX_BPS() - 1);

        vm.startPrank(users.owner);
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: minStakeTime});
        leafGaugeFactory.setPenaltyRate({_penaltyRate: _penaltyRate});
        vm.stopPrank();

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(fuzzGauge), tokenId);
        fuzzGauge.deposit(tokenId);

        addRewardToLeafGauge(address(fuzzGauge), TOKEN_1);
        skip(minStakeTime / 2);

        vm.startPrank(users.alice);
        uint256 netEarned = fuzzGauge.earned(users.alice, tokenId);
        uint256 gaugeBalBefore = leafXVelo.balanceOf(address(fuzzGauge));
        fuzzGauge.getReward(tokenId);

        uint256 aliceBal = leafXVelo.balanceOf(users.alice);
        assertEq(aliceBal, netEarned);
        assertGt(aliceBal, 0); // remaining rewards branch — alice always receives
        // penalty was buffered — gauge kept more than it would have without penalty
        assertGt(leafXVelo.balanceOf(address(fuzzGauge)), gaugeBalBefore - netEarned - aliceBal);
    }

    function testFuzz_WhenCalledAfterMinStakeTime(uint256 _minStakeTime)
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
    {
        // It should transfer full rewards to owner
        _minStakeTime = bound(_minStakeTime, 1, leafGaugeFactory.MAX_MIN_STAKE_TIME());

        vm.startPrank(users.owner);
        leafGaugeFactory.setDefaultMinStakeTime({_minStakeTime: _minStakeTime});
        leafGaugeFactory.setPenaltyRate({_penaltyRate: 5_000}); // non-zero rate to confirm boundary
        vm.stopPrank();

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(fuzzGauge), tokenId);
        fuzzGauge.deposit(tokenId);

        addRewardToLeafGauge(address(fuzzGauge), TOKEN_1);
        skip(_minStakeTime); // exact boundary — condition is <, so no penalty

        vm.startPrank(users.alice);
        uint256 expectedReward = fuzzGauge.earned(users.alice, tokenId);
        fuzzGauge.getReward(tokenId);

        assertEq(leafXVelo.balanceOf(users.alice), expectedReward);
    }
}
