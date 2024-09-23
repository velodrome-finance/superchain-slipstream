pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLLeafGaugeFactory.t.sol";
import {CLLeafGauge} from "contracts/gauge/CLLeafGauge.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CreateGaugeTest is CLLeafGaugeFactoryTest {
    address public pool;

    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: address(leafVoter)});
    }

    function test_RevertIf_NotVoter() public {
        pool = poolFactory.createPool({
            tokenA: TEST_TOKEN_0,
            tokenB: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NV"));
        leafGaugeFactory.createGauge({_pool: address(pool), _feesVotingReward: address(0), _isPool: true});
    }

    function test_CreateGauge() public {
        pool = poolFactory.createPool({
            tokenA: TEST_TOKEN_0,
            tokenB: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.startPrank(address(leafVoter));

        address[] memory rewards = new address[](2);
        rewards[0] = ICLPool(pool).token0();
        rewards[1] = ICLPool(pool).token1();
        (address feesVotingReward, address bribeVotingReward) =
            IVotingRewardsFactory(votingRewardsFactory).createRewards(forwarder, rewards);
        CLLeafGauge gauge = CLLeafGauge(
            leafGaugeFactory.createGauge({_pool: address(pool), _feesVotingReward: feesVotingReward, _isPool: true})
        );

        assertEq(address(gauge.voter()), address(leafVoter));
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(xVelo));
        assertEq(gauge.isPool(), true);

        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.token0(), rewards[0]);
        assertEq(gauge.token1(), rewards[1]);
        assertEq(gauge.tickSpacing(), TICK_SPACING_LOW);
        assertEq(gauge.feesVotingReward(), feesVotingReward);
        assertEq(gauge.rewardToken(), address(xVelo));
        assertEq(address(gauge.voter()), address(leafVoter));
        assertEq(address(gauge.nft()), address(nft));
        assertEq(gauge.bridge(), address(leafMessageBridge));
        assertEq(gauge.isPool(), true);
    }
}
