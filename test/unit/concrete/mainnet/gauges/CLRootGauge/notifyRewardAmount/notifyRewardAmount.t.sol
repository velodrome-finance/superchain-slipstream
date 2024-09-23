// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLRootGauge.t.sol";

contract NotifyRewardAmountIntegrationConcreteTest is CLRootGaugeTest {
    function test_WhenTheCallerIsNotVoter() external {
        // It should revert with NotVoter
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodePacked("NV"));
        rootGauge.notifyRewardAmount({_amount: 0});
    }

    modifier whenTheCallerIsVoter() {
        vm.prank(address(rootVoter));
        _;
    }

    function test_WhenTheCurrentTimestampIsGreaterThanOrEqualToPeriodFinish() external whenTheCallerIsVoter {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        uint256 amount = TOKEN_1 * 1_000;
        // uint256 bufferCap = amount * 2;
        // setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        deal({token: address(rewardToken), to: address(rootVoter), give: amount});
        vm.prank(address(rootVoter));
        rewardToken.approve({spender: address(rootGauge), amount: amount});

        assertEq(rootGauge.rewardToken(), address(rewardToken));

        vm.prank({msgSender: address(rootVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit NotifyReward({from: address(rootVoter), amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(rewardToken.balanceOf(address(rootVoter)), 0);
        assertEq(rewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(xVelo.balanceOf(address(rootGauge)), 0);

        // vm.selectFork({forkId: leafId});
        // vm.expectEmit(address(leafGauge));
        // emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: amount});
        // leafMailbox.processNextInboundMessage();
        // assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
        //
        // assertEq(leafGauge.rewardPerTokenStored(), 0);
        // assertEq(leafGauge.rewardRate(), amount / WEEK);
        // assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), amount / WEEK);
        // assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        // assertEq(leafGauge.periodFinish(), block.timestamp + WEEK);
    }

    function test_WhenTheCurrentTimestampIsLessThanPeriodFinish() external whenTheCallerIsVoter {
        // It should wrap the tokens to the XERC20 token
        // It should bridge the XERC20 token to the corresponding LeafGauge
        // It should update rewardPerTokenStored
        // It should deposit the amount of XERC20 token
        // It should update the reward rate, including any existing rewards
        // It should cache the updated reward rate for this epoch
        // It should update the last update timestamp
        // It should update the period finish timestamp
        // It should emit a {NotifyReward} event
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 2});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), amount: MESSAGE_FEE * 2});

        uint256 amount = TOKEN_1 * 1_000;
        // uint256 bufferCap = amount * 2;
        // setLimits({_rootBufferCap: bufferCap, _leafBufferCap: bufferCap});

        deal({token: address(rewardToken), to: address(rootVoter), give: amount * 2});
        vm.prank(address(rootVoter));
        rewardToken.approve({spender: address(rootGauge), amount: amount * 2});

        // inital deposit of partial amount
        vm.prank({msgSender: address(rootVoter), txOrigin: users.alice});
        rootGauge.notifyRewardAmount({_amount: amount});
        // vm.selectFork({forkId: leafId});
        // leafMailbox.processNextInboundMessage();
        //
        // skipTime(WEEK / 7 * 5);
        //
        vm.selectFork({forkId: rootId});
        vm.prank({msgSender: address(rootVoter), txOrigin: users.alice});
        vm.expectEmit(address(rootGauge));
        emit NotifyReward({from: address(rootVoter), amount: amount});
        rootGauge.notifyRewardAmount({_amount: amount});

        assertEq(rewardToken.balanceOf(address(rootVoter)), 0);
        assertEq(rewardToken.balanceOf(address(rootGauge)), 0);
        assertEq(xVelo.balanceOf(address(rootGauge)), 0);

        // vm.selectFork({forkId: leafId});
        // vm.expectEmit(address(leafGauge));
        // emit ILeafGauge.NotifyReward({_sender: address(leafMessageModule), _amount: amount});
        // leafMailbox.processNextInboundMessage();
        // assertEq(leafXVelo.balanceOf(address(leafGauge)), amount * 2);
        //
        // assertEq(leafGauge.rewardPerTokenStored(), 0);
        // uint256 timeUntilNext = WEEK * 2 / 7;
        // uint256 rewardRate = ((amount / WEEK) * timeUntilNext + amount) / timeUntilNext;
        // assertEq(leafGauge.rewardRate(), rewardRate);
        // assertEq(leafGauge.rewardRateByEpoch(VelodromeTimeLibrary.epochStart(block.timestamp)), rewardRate);
        // assertEq(leafGauge.lastUpdateTime(), block.timestamp);
        // assertEq(leafGauge.periodFinish(), block.timestamp + WEEK / 7 * 2);
    }
}
