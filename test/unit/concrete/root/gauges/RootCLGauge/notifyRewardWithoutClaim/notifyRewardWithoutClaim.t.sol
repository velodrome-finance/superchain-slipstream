// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLGauge.t.sol";

contract NotifyRewardWithoutClaimIntegrationConcreteTest is RootCLGaugeTest {
    uint256 amount;

    function test_WhenTheCallerIsNotNotifyAdmin() external {
        // It should revert with NotAuthorized
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        rootGauge.notifyRewardWithoutClaim(0);
    }

    modifier whenTheCallerIsNotifyAdmin() {
        vm.startPrank({msgSender: users.owner, txOrigin: users.alice});
        _;
    }

    function test_WhenTheAmountIsSmallerThanTheTimeInAWeek() external whenTheCallerIsNotifyAdmin {
        // It should revert with ZeroRewardRate
        vm.expectRevert(abi.encodePacked("ZRR"));
        amount = VelodromeTimeLibrary.WEEK - 1;
        rootGauge.notifyRewardWithoutClaim({_amount: amount});
    }

    modifier whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek() {
        amount = TOKEN_1 * 1_000;
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish()
        external
        whenTheCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek
    {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should deposit the amount of XERC20 token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event

        deal({token: address(rewardToken), to: users.owner, give: amount});
        rewardToken.approve({spender: address(rootGauge), amount: amount});

        uint256 bufferCap = amount * 2;
        setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        assertEq(rootGauge.rewardToken(), address(rewardToken));

        vm.startPrank({msgSender: users.owner, txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit NotifyReward({from: users.owner, amount: amount});
        rootGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(rewardToken.balanceOf(users.owner), 0);
        assertEq(rewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafGauge));
        emit NotifyReward({from: address(leafMessageModule), amount: amount});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);

        assertEq(leafGauge.rewardRate(), amount / WEEK);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / WEEK);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
        assertEq(leafPool.rewardRate(), amount / WEEK);
        assertEq(leafPool.rewardReserve(), amount);
        assertEq(leafPool.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish()
        external
        whenTheCallerIsNotifyAdmin
        whenTheAmountIsGreaterThanOrEqualToTheTimeInAWeek
    {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should deposit the amount of XERC20 token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event

        deal({token: address(rewardToken), to: users.owner, give: amount * 2});
        rewardToken.approve({spender: address(rootGauge), amount: amount * 2});

        uint256 bufferCap = amount * 2;
        setLimits({_rootBufferCap: bufferCap * 2, _leafBufferCap: bufferCap * 2});

        // inital deposit of partial amount
        vm.prank({msgSender: users.owner, txOrigin: users.alice});
        rootGauge.notifyRewardWithoutClaim({_amount: amount});
        vm.selectFork({forkId: leafId});
        leafMailbox.processNextInboundMessage();

        skipTime(WEEK / 7 * 5);

        vm.selectFork({forkId: rootId});
        vm.prank({msgSender: users.owner, txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit NotifyReward({from: users.owner, amount: amount});
        rootGauge.notifyRewardWithoutClaim({_amount: amount});

        assertEq(rewardToken.balanceOf(users.owner), 0);
        assertEq(rewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: leafId});
        uint256 timeUntilNext = WEEK * 2 / 7;

        assertEq(leafPool.rewardRate(), amount / WEEK);
        assertEq(leafPool.rewardReserve(), amount);
        assertEq(leafPool.periodFinish(), block.timestamp + timeUntilNext);

        uint256 poolRollover = amount / WEEK * (WEEK / 7 * 5);

        vm.expectEmit(address(leafGauge));
        emit NotifyReward({from: address(leafMessageModule), amount: amount + poolRollover});
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount * 2);

        uint256 rewardRate = ((amount / WEEK) * timeUntilNext + amount + poolRollover) / timeUntilNext;
        assertEq(leafGauge.rewardRate(), rewardRate);
        assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
        assertEq(leafPool.rewardRate(), rewardRate);
        assertEq(leafPool.rewardReserve(), amount + poolRollover + ((amount / WEEK) * timeUntilNext));
        assertEq(leafPool.periodFinish(), block.timestamp + (WEEK / 7 * 2));
    }
}
