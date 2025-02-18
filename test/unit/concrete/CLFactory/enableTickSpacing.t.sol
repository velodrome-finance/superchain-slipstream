pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest, ICLPool} from "./CLFactory.t.sol";

contract EnableTickSpacingTest is CLFactoryTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank({msgSender: users.owner});
    }

    function test_RevertIf_NotOwner() public {
        resetPrank({msgSender: users.charlie});
        vm.expectRevert();
        leafPoolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});
    }

    function test_RevertIf_TickSpacingTooSmall() public {
        vm.expectRevert();
        leafPoolFactory.enableTickSpacing({tickSpacing: 0, fee: 5_000});
    }

    function test_RevertIf_TickSpacingTooLarge() public {
        vm.expectRevert();
        leafPoolFactory.enableTickSpacing({tickSpacing: 16_834, fee: 5_000});
    }

    function test_RevertIf_TickSpacingAlreadyEnabled() public {
        leafPoolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});
        vm.expectRevert();
        leafPoolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});
    }

    function test_RevertIf_FeeTooHigh() public {
        vm.expectRevert();
        leafPoolFactory.enableTickSpacing({tickSpacing: 250, fee: 1_000_000});
    }

    function test_RevertIf_FeeIsZero() public {
        vm.expectRevert();
        leafPoolFactory.enableTickSpacing({tickSpacing: 250, fee: 0});
    }

    function test_EnableTickSpacing() public {
        vm.expectEmit(true, false, false, false, address(leafPoolFactory));
        emit TickSpacingEnabled({tickSpacing: 250, fee: 5_000});
        leafPoolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});

        assertEqUint(leafPoolFactory.tickSpacingToFee(250), 5_000);
        assertEq(leafPoolFactory.tickSpacings().length, 8);
        assertEq(leafPoolFactory.tickSpacings()[7], 250);

        createAndCheckPool({
            factory: leafPoolFactory,
            _token0: TEST_TOKEN_0,
            _token1: TEST_TOKEN_1,
            tickSpacing: 250,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }
}
