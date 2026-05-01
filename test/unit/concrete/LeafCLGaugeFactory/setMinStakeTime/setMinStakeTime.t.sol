pragma solidity ^0.7.6;
pragma abicoder v2;

import "../LeafCLGaugeFactory.t.sol";

contract SetMinStakeTimeConcreteUnitTest is LeafCLGaugeFactoryTest {
    address public pool;

    function setUp() public override {
        super.setUp();
        pool = leafPoolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: TICK_SPACING_60,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }

    function test_WhenTheCallerIsNotTheGaugeStakeManager() external {
        // It should revert with {NA}
        vm.prank({msgSender: users.charlie});
        vm.expectRevert(abi.encodePacked("NA"));
        leafGaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 60});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function test_WhenThePoolIsTheZeroAddress() external whenTheCallerIsTheGaugeStakeManager {
        // It should revert with {ZA}
        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("ZA"));
        leafGaugeFactory.setMinStakeTime({_pool: address(0), _minStakeTime: 60});
    }

    modifier whenThePoolIsNotTheZeroAddress() {
        _;
    }

    function test_WhenTheMinStakeTimeExceedsTheMaximum()
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should revert with {MS}
        uint256 tooHigh = leafGaugeFactory.MAX_MIN_STAKE_TIME() + 1;
        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("MS"));
        leafGaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: tooHigh});
    }

    function test_WhenTheMinStakeTimeDoesNotExceedTheMaximum()
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should set the per-pool min stake time
        // It should emit a {SetPoolMinStakeTime} event
        vm.prank({msgSender: users.owner});
        vm.expectEmit(address(leafGaugeFactory));
        emit SetPoolMinStakeTime({_pool: pool, _minStakeTime: 120});
        leafGaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 120});

        assertEq(leafGaugeFactory.minStakeTimes(pool), 120);
    }
}
