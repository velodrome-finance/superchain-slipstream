// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../RootCLPoolFactory.t.sol";

contract CreatePoolConcreteTest is RootCLPoolFactoryTest {
    TestERC20 public tokenA;
    TestERC20 public tokenB;

    uint256 _chainid = 1_000;

    int24 _tickSpacing = TICK_SPACING_LOW;

    function setUp() public override {
        super.setUp();

        tokenA = new TestERC20(TOKEN_1 * 100);
        tokenB = new TestERC20(USDC_1 * 100); // mimic USDC
    }

    function test_WhenChainIdIsNotRegistered() external {
        // It reverts with {NotRegistered}
        vm.expectRevert(bytes("NR"));
        rootPoolFactory.createPool({
            chainid: _chainid,
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tickSpacing: _tickSpacing
        });
    }

    modifier whenChainIdIsRegistered() {
        vm.startPrank(Ownable(address(rootMessageBridge)).owner());
        IChainRegistry(address(rootMessageBridge)).registerChain({
            _chainid: _chainid,
            _module: address(rootMessageModule)
        });
        vm.stopPrank();
        _;
    }

    function test_WhenTokenAIsTheSameAsTokenB() external whenChainIdIsRegistered {
        // It reverts with {SameAddress}
        vm.expectRevert(bytes("S_A"));
        rootPoolFactory.createPool({
            chainid: _chainid,
            tokenA: address(tokenA),
            tokenB: address(tokenA),
            tickSpacing: _tickSpacing
        });
    }

    modifier whenTokenAIsNotTheSameAsTokenB() {
        _;
    }

    function test_WhenToken0IsTheZeroAddress() external whenChainIdIsRegistered whenTokenAIsNotTheSameAsTokenB {
        // It reverts with {ZeroAddress}
        vm.expectRevert(bytes("Z_A"));
        rootPoolFactory.createPool({
            chainid: _chainid,
            tokenA: address(0),
            tokenB: address(tokenB),
            tickSpacing: _tickSpacing
        });
    }

    modifier whenToken0IsNotTheZeroAddress() {
        _;
    }

    function test_WhenThePoolAlreadyExists()
        external
        whenChainIdIsRegistered
        whenTokenAIsNotTheSameAsTokenB
        whenToken0IsNotTheZeroAddress
    {
        // It reverts with {PoolAlreadyExists}
        rootPoolFactory.createPool({
            chainid: _chainid,
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tickSpacing: _tickSpacing
        });

        vm.expectRevert(bytes("AE"));
        rootPoolFactory.createPool({
            chainid: _chainid,
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tickSpacing: _tickSpacing
        });
    }

    function test_WhenThePoolDoesNotExist()
        external
        whenChainIdIsRegistered
        whenTokenAIsNotTheSameAsTokenB
        whenToken0IsNotTheZeroAddress
    {
        // It creates the pool using Create2
        // It populates the getPool mapping in both directions
        // It adds the pool to the list of all pools
        // It emits {PoolCreated}
        address pool = rootPoolFactory.createPool({
            chainid: _chainid,
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tickSpacing: _tickSpacing
        });

        (address token0, address token1) =
            tokenA < tokenB ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        address expected = Clones.predictDeterministicAddress({
            master: rootPoolFactory.poolImplementation(),
            salt: keccak256(abi.encodePacked(_chainid, token0, token1, _tickSpacing)),
            deployer: address(rootPoolFactory)
        });

        assertEq(pool, expected);
        assertEq(rootPoolFactory.getPool(address(tokenA), address(tokenB), _tickSpacing), pool);
        assertEq(rootPoolFactory.getPool(address(tokenB), address(tokenA), _tickSpacing), pool);
        assertEq(rootPoolFactory.allPools(1), pool);
    }
}
