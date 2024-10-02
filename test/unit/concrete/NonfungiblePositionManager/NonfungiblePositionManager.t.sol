pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseForkFixture.sol";

contract NonfungiblePositionManagerTest is BaseForkFixture {
    CLPool public pool;
    LeafCLGauge public gauge;

    function setUp() public virtual override {
        super.setUp();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        vm.prank(address(leafMessageModule));
        gauge = LeafCLGauge(
            leafVoter.createGauge({
                _poolFactory: address(poolFactory),
                _pool: address(pool),
                _votingRewardsFactory: address(votingRewardsFactory),
                _gaugeFactory: address(leafGaugeFactory)
            })
        );

        vm.startPrank(users.alice);
        token0.approve(address(gauge), type(uint256).max);
        token1.approve(address(gauge), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(nft.factory(), address(poolFactory));
        assertEq(nft.WETH9(), address(weth));
        assertEq(nft.name(), "Slipstream Position NFT v1");
        assertEq(nft.symbol(), "CL-POS");
    }
}
