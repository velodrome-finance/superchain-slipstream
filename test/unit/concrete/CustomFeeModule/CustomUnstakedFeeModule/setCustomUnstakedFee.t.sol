pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CustomUnstakedFeeModule.t.sol";

contract SetCustomUnstakedFeeTest is CustomUnstakedFeeModuleTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotManager() public {
        resetPrank({msgSender: users.charlie});
        vm.expectRevert();
        customUnstakedFeeModule.setCustomFee({pool: address(1), fee: 5_000});
    }

    function test_RevertIf_FeeTooHigh() public {
        address pool = createAndCheckPool({
            factory: leafPoolFactory,
            _token0: TEST_TOKEN_0,
            _token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.expectRevert();
        customUnstakedFeeModule.setCustomFee({pool: pool, fee: 500_001});
    }

    function test_RevertIf_NotPool() public {
        vm.expectRevert();
        customUnstakedFeeModule.setCustomFee({pool: address(1), fee: 5_000});
    }

    function test_SetCustomFee() public {
        address pool = createAndCheckPool({
            factory: leafPoolFactory,
            _token0: TEST_TOKEN_0,
            _token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        vm.startPrank(address(leafMessageModule));
        leafVoter.createGauge({
            _poolFactory: address(leafPoolFactory),
            _pool: address(pool),
            _votingRewardsFactory: address(votingRewardsFactory),
            _gaugeFactory: address(leafGaugeFactory)
        });

        vm.startPrank(users.feeManager);

        vm.expectEmit(true, true, false, false, address(customUnstakedFeeModule));
        emit SetCustomFee({pool: pool, fee: 5_000});
        customUnstakedFeeModule.setCustomFee({pool: pool, fee: 5_000});

        assertEqUint(customUnstakedFeeModule.customFee(pool), 5_000);
        assertEqUint(customUnstakedFeeModule.getFee(pool), 5_000);
        assertEqUint(leafPoolFactory.getUnstakedFee(pool), 5_000);

        // revert to default fee
        vm.expectEmit(true, true, false, false, address(customUnstakedFeeModule));
        emit SetCustomFee({pool: pool, fee: 0});
        customUnstakedFeeModule.setCustomFee({pool: pool, fee: 0});

        assertEqUint(customUnstakedFeeModule.customFee(pool), 0);
        assertEqUint(customUnstakedFeeModule.getFee(pool), 100_000);
        assertEqUint(leafPoolFactory.getUnstakedFee(pool), 100_000);

        // zero fee
        vm.expectEmit(true, true, false, false, address(customUnstakedFeeModule));
        emit SetCustomFee({pool: pool, fee: 420});
        customUnstakedFeeModule.setCustomFee({pool: pool, fee: 420});

        assertEqUint(customUnstakedFeeModule.customFee(pool), 420);
        assertEqUint(customUnstakedFeeModule.getFee(pool), 0);
        assertEqUint(leafPoolFactory.getUnstakedFee(pool), 0);
    }

    function test_CannotExceedMaxUnstakedFee() public {
        address pool = createAndCheckPool({
            factory: leafPoolFactory,
            _token0: TEST_TOKEN_0,
            _token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        vm.startPrank(address(leafMessageModule));
        leafVoter.createGauge({
            _poolFactory: address(leafPoolFactory),
            _pool: address(pool),
            _votingRewardsFactory: address(votingRewardsFactory),
            _gaugeFactory: address(leafGaugeFactory)
        });
        vm.startPrank(users.feeManager);

        uint24 maxFee = 1_000_000;
        uint24 defaultFee = 100_000;

        // simulating a malicious UnstakedFeeModule without max fees
        vm.mockCall(
            address(customUnstakedFeeModule),
            abi.encodeWithSelector(CustomUnstakedFeeModule.getFee.selector, pool),
            abi.encode(maxFee)
        );

        // malicious Fee module with max fees
        assertEqUint(customUnstakedFeeModule.getFee(pool), maxFee);
        // max fee still allowed by PoolFactory
        assertEqUint(leafPoolFactory.getUnstakedFee(pool), maxFee);

        vm.mockCall(
            address(customUnstakedFeeModule),
            abi.encodeWithSelector(CustomUnstakedFeeModule.getFee.selector, pool),
            abi.encode(maxFee + 1)
        );

        // malicious Fee module with exceedingly large fees
        assertEqUint(customUnstakedFeeModule.getFee(pool), maxFee + 1);
        // if fee is too large, PoolFactory returns defaultFee
        assertEqUint(leafPoolFactory.getUnstakedFee(pool), defaultFee);
    }
}
