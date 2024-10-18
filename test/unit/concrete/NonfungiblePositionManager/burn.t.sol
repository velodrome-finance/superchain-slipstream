pragma solidity ^0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import "./NonfungiblePositionManager.t.sol";

contract BurnTest is NonfungiblePositionManagerTest {
    function test_Burn() public {
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: getMinTick(TICK_SPACING_60),
            tickUpper: getMaxTick(TICK_SPACING_60),
            recipient: users.alice,
            amount0Desired: 15,
            amount1Desired: 15,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp + 10,
            sqrtPriceX96: 0
        });
        (uint256 tokenId, uint128 liquidity,,) = nft.mint(params);
        nft.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp + 10
            })
        );
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: users.alice,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        nft.burn(tokenId);
        assertEq(nft.balanceOf(users.alice), 0);

        vm.expectRevert("ERC721: owner query for nonexistent token");
        nft.ownerOf(tokenId);

        uint256[] memory userPositions = nft.userPositions(users.alice, address(pool));
        assertEq(userPositions.length, 0);
    }
}
