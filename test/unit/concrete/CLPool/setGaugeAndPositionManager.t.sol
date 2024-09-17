pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLPool.t.sol";

contract SetGaugeAndPositionManagerTest is CLPoolTest {
    CLPool public pool;

    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.owner});

        // redeploy contracts
        factoryRegistry = IFactoryRegistry(new MockFactoryRegistry());
        leafMessageBridge = ILeafMessageBridge(address(0)); // TODO: for now it is zero address, later it should be from a fork

        leafVoter = ILeafVoter(
            new LeafVoter({
                _factoryRegistry: address(factoryRegistry),
                _emergencyCouncil: users.owner, // emergency council
                _messageBridge: address(leafMessageBridge) // message bridge
            })
        );

        poolImplementation = new CLPool();
        poolFactory = new CLFactory({
            _owner: users.owner,
            _swapFeeManager: address(this),
            _unstakedFeeManager: address(this),
            _voter: address(leafVoter),
            _poolImplementation: address(poolImplementation)
        });

        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: address(weth),
            _nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000 // 'ETH' as bytes32 string
        });
        nft = new NonfungiblePositionManager({
            _owner: users.owner,
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor),
            name: nftName,
            symbol: nftSymbol
        });

        // gaugeImplementation = new CLLeafGauge();
        leafGaugeFactory = new CLLeafGaugeFactory({
            _voter: address(leafVoter),
            _nft: address(nft),
            _factory: address(poolFactory),
            _xerc20: address(0),
            _bridge: address(0)
        });

        factoryRegistry.approve({
            poolFactory: address(poolFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            gaugeFactory: address(leafGaugeFactory)
        });
        vm.stopPrank();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_LOW,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );

        vm.label(address(leafGaugeFactory), "GF");
        vm.label(address(factoryRegistry), "FR");
    }

    function test_RevertIf_AlreadyInitialized() public {
        vm.prank(address(leafGaugeFactory));
        pool.setGaugeAndPositionManager({_gauge: address(1), _nft: address(nft)});

        vm.prank(address(leafGaugeFactory));
        vm.expectRevert();
        pool.setGaugeAndPositionManager({_gauge: address(1), _nft: address(nft)});
    }

    function test_RevertIf_NotGaugeFactory() public {
        vm.expectRevert(abi.encodePacked("NGF"));
        pool.setGaugeAndPositionManager({_gauge: address(1), _nft: address(nft)});
    }

    function test_SetGaugeAndPositionManager() public {
        address gauge = leafVoter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)});

        assertEq(pool.gauge(), address(gauge));
        assertEq(pool.nft(), address(nft));
    }
}
