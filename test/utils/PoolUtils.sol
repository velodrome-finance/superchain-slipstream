pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactory} from "contracts/core/CLFactory.sol";
import {SafeCast} from "contracts/core/libraries/SafeCast.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {TestConstants} from "./TestConstants.sol";
import {Events} from "./Events.sol";
import "forge-std/Test.sol";

abstract contract PoolUtils is Test, TestConstants, Events {
    function computeAddress(address factory, address tokenA, address tokenB, int24 tickSpacing)
        internal
        view
        returns (address _pool)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address implementation = CLFactory(factory).poolImplementation();
        return Clones.predictDeterministicAddress({
            master: address(implementation),
            salt: keccak256(abi.encode(token0, token1, tickSpacing)),
            deployer: address(factory)
        });
    }

    /// @dev Use only with test addresses
    function createAndCheckPool(
        CLFactory factory,
        address token0,
        address token1,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    ) internal returns (address _pool) {
        address create2Addr =
            computeAddress({factory: address(factory), tokenA: token0, tokenB: token1, tickSpacing: tickSpacing});

        vm.expectEmit(true, true, true, true, address(factory));
        emit PoolCreated({token0: TEST_TOKEN_0, token1: TEST_TOKEN_1, tickSpacing: tickSpacing, pool: create2Addr});

        CLPool pool = CLPool(factory.createPool(token0, token1, tickSpacing, sqrtPriceX96));
        (uint160 _sqrtPriceX96,,,,,) = pool.slot0();

        assertGt(factory.allPoolsLength(), 0);
        assertEq(factory.allPools(factory.allPoolsLength() - 1), create2Addr);
        assertEq(factory.getPool(token0, token1, tickSpacing), create2Addr);
        assertEq(factory.getPool(token1, token0, tickSpacing), create2Addr);
        assertEq(factory.isPair(create2Addr), true);
        assertEq(pool.factory(), address(factory));
        assertEq(pool.token0(), TEST_TOKEN_0);
        assertEq(pool.token1(), TEST_TOKEN_1);
        assertEq(pool.tickSpacing(), tickSpacing);
        assertEq(pool.factoryRegistry(), address(factory.factoryRegistry()));
        assertEq(pool.gauge(), address(0));
        assertEq(pool.nft(), address(0));
        assertEq(uint256(_sqrtPriceX96), uint256(sqrtPriceX96));

        return address(pool);
    }

    function encodePriceSqrt(uint256 reserve1, uint256 reserve0) public pure returns (uint160) {
        reserve1 = reserve1 * 2 ** 192;
        uint256 division = reserve1 / reserve0;
        uint256 sqrtX96 = sqrt(division);

        return SafeCast.toUint160(sqrtX96);
    }

    function getScaledExecutionPrice(int256 poolBalance1Delta, int256 poolBalance0Delta) public pure returns (int256) {
        return (poolBalance1Delta * 10 ** 39) / poolBalance0Delta * -1;
    }

    // @dev converts positive numbers to string
    function stringToUint(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getMinTick(int24 tickSpacing) public pure returns (int24) {
        return (-887272 / tickSpacing) * tickSpacing;
    }

    function getMaxTick(int24 tickSpacing) public pure returns (int24) {
        return (887272 / tickSpacing) * tickSpacing;
    }
}
