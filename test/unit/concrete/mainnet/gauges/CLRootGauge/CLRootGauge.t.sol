pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../../BaseForkFixture.sol";

abstract contract CLRootGaugeTest is BaseForkFixture {
    using CreateXLibrary for bytes11;

    CLRootGauge public rootGauge;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: rootId});
        vm.prank(Ownable(address(rootMessageBridge)).owner());
        IChainRegistry(address(rootMessageBridge)).registerChain({_chainid: leafChainId});
        address rootPool = address(
            rootPoolFactory.createPool({
                chainid: leafChainId,
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: 1,
                sqrtPriceX96: 79228162514264337593543950336
            })
        );
        vm.label({account: rootPool, newLabel: "Root Pool"});
        // fund alice for gauge creation below
        deal({token: address(weth), to: users.alice, give: MESSAGE_FEE * 4});
        vm.prank(users.alice);
        weth.approve({spender: address(rootMessageBridge), amount: MESSAGE_FEE * 4});

        vm.prank({msgSender: rootVoter.governor(), txOrigin: users.alice});
        rootGauge = CLRootGauge(rootVoter.createGauge({_poolFactory: address(rootPoolFactory), _pool: rootPool}));
    }
}
