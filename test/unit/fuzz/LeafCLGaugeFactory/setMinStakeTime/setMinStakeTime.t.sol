pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../concrete/LeafCLGaugeFactory/LeafCLGaugeFactory.t.sol";

contract SetMinStakeTimeConcreteFuzzTest is LeafCLGaugeFactoryTest {
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

    function testFuzz_WhenTheCallerIsNotTheGaugeStakeManager(address _caller) external {
        // It should revert with {NA}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodePacked("NA"));
        leafGaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 60});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function testFuzz_WhenThePoolIsTheZeroAddress() external whenTheCallerIsTheGaugeStakeManager {
        // not fuzzed: zero address is a single discrete value
    }

    modifier whenThePoolIsNotTheZeroAddress() {
        _;
    }

    function testFuzz_WhenTheMinStakeTimeExceedsTheMaximum(uint256 _minStakeTime)
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should revert with {MS}
        uint256 tooHigh = leafGaugeFactory.MAX_MIN_STAKE_TIME() + 1;
        _minStakeTime = bound(_minStakeTime, tooHigh, type(uint256).max);
        vm.prank(users.owner);
        vm.expectRevert(abi.encodePacked("MS"));
        leafGaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: _minStakeTime});
    }

    function testFuzz_WhenTheMinStakeTimeDoesNotExceedTheMaximum(uint256 _minStakeTime)
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should set the per-pool min stake time
        _minStakeTime = bound(_minStakeTime, 0, leafGaugeFactory.MAX_MIN_STAKE_TIME());
        vm.prank(users.owner);
        leafGaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: _minStakeTime});

        assertEq(
            leafGaugeFactory.minStakeTimes(pool),
            _minStakeTime == 0 ? leafGaugeFactory.defaultMinStakeTime() : _minStakeTime
        );
    }
}
