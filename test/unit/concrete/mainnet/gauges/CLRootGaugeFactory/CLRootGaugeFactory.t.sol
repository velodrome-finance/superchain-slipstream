// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../fork/BaseForkFixture.sol";

abstract contract CLRootGaugeFactoryTest is BaseForkFixture {
    using CreateXLibrary for bytes11;

    RootCLPool public rootPool;

    function setUp() public virtual override {
        super.setUp();
        // use users.alice as tx.origin
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), amount: MESSAGE_FEE});

        vm.prank(Ownable(address(rootMessageBridge)).owner());
        IChainRegistry(address(rootMessageBridge)).registerChain({_chainid: leaf});

        rootPool = RootCLPool(
            rootPoolFactory.createPool({
                chainid: leaf,
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: 1,
                sqrtPriceX96: 79228162514264337593543950336
            })
        );
    }

    function test_InitialState() public view {
        assertEq(rootGaugeFactory.voter(), address(rootVoter));
        assertEq(rootGaugeFactory.xerc20(), address(xVelo));
        assertEq(rootGaugeFactory.lockbox(), address(rootLockbox));
        assertEq(rootGaugeFactory.messageBridge(), address(rootMessageBridge));
        assertEq(rootGaugeFactory.poolFactory(), address(rootPoolFactory));
        assertEq(rootGaugeFactory.votingRewardsFactory(), address(rootVotingRewardsFactory));
        assertEq(rootGaugeFactory.notifyAdmin(), users.owner);
    }
}
