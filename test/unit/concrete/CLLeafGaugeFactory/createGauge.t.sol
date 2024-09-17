pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLLeafGaugeFactoryTest} from "./CLLeafGaugeFactory.t.sol";
import {CLLeafGauge} from "contracts/gauge/CLLeafGauge.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CreateGaugeTest is CLLeafGaugeFactoryTest {
    address public pool;
    address public feesVotingReward;

    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: address(leafVoter)});
    }

    function test_RevertIf_NotVoter() public {
        // pool = poolFactory.createPool({
        //     tokenA: TEST_TOKEN_0,
        //     tokenB: TEST_TOKEN_1,
        //     tickSpacing: TICK_SPACING_LOW,
        //     sqrtPriceX96: encodePriceSqrt(1, 1)
        // });
        // vm.expectRevert(abi.encodePacked("NV"));
        // vm.startPrank(users.charlie);
        // CLLeafGauge(leafGaugeFactory.createGauge(forwarder, pool, address(feesVotingReward), address(rewardToken), true));
    }

    function test_CreateGauge() public {
        pool = poolFactory.createPool({
            tokenA: TEST_TOKEN_0,
            tokenB: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        CLLeafGauge gauge =
            CLLeafGauge(leafVoter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));
        feesVotingReward = leafVoter.gaugeToFees(address(gauge));

        assertEq(address(gauge.voter()), address(leafVoter));
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertEq(gauge.isPool(), true);
    }
}
