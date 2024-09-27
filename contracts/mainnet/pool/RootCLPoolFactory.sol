// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IRootCLPoolFactory} from "./IRootCLPoolFactory.sol";
import {IRootCLPool} from "./IRootCLPool.sol";
import {IVoter} from "../../core/interfaces/IVoter.sol";
import {IChainRegistry} from "../../mainnet/interfaces/bridge/IChainRegistry.sol";
import "../../core/interfaces/IFactoryRegistry.sol";

/// @notice Factory for creating RootPools
contract RootCLPoolFactory is IRootCLPoolFactory {
    /// @inheritdoc IRootCLPoolFactory
    address public immutable override poolImplementation;
    /// @inheritdoc IRootCLPoolFactory
    address public immutable override bridge;
    /// @inheritdoc IRootCLPoolFactory
    address public override owner;
    /// @inheritdoc IRootCLPoolFactory
    mapping(int24 => uint24) public override tickSpacingToFee;
    /// @inheritdoc IRootCLPoolFactory
    mapping(address => mapping(address => mapping(int24 => address))) public override getPool;
    /// @dev Used in VotingEscrow to determine if a contract is a valid pool
    mapping(address => bool) private _isPool;
    /// @inheritdoc IRootCLPoolFactory
    address[] public override allPools;

    int24[] private _tickSpacings;

    constructor(address _owner, address _poolImplementation, address _bridge) {
        owner = _owner;
        poolImplementation = _poolImplementation;
        bridge = _bridge;

        _enableTickSpacing(1, 100);
        _enableTickSpacing(50, 500);
        _enableTickSpacing(100, 500);
        _enableTickSpacing(200, 3_000);
        _enableTickSpacing(2_000, 10_000);
    }

    /// @inheritdoc IRootCLPoolFactory
    function createPool(uint256 chainid, address tokenA, address tokenB, int24 tickSpacing)
        external
        override
        returns (address pool)
    {
        require(IChainRegistry(bridge).containsChain(chainid), "NR");
        require(tokenA != tokenB, "S_A");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Z_A");
        require(tickSpacingToFee[tickSpacing] != 0);
        require(getPool[token0][token1][tickSpacing] == address(0), "AE");
        pool = Clones.cloneDeterministic({
            master: poolImplementation,
            salt: keccak256(abi.encodePacked(chainid, token0, token1, tickSpacing))
        });
        IRootCLPool(pool).initialize({
            _chainId: chainid,
            _factory: address(this),
            _token0: token0,
            _token1: token1,
            _tickSpacing: tickSpacing
        });
        allPools.push(pool);
        _isPool[pool] = true;
        getPool[token0][token1][tickSpacing] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][tickSpacing] = pool;
        emit RootPoolCreated(token0, token1, tickSpacing, pool);
    }

    /// @inheritdoc IRootCLPoolFactory
    function setOwner(address _owner) external override {
        address cachedOwner = owner;
        require(msg.sender == cachedOwner);
        require(_owner != address(0));
        emit OwnerChanged(cachedOwner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IRootCLPoolFactory
    function enableTickSpacing(int24 tickSpacing, uint24 fee) public override {
        require(msg.sender == owner);
        _enableTickSpacing(tickSpacing, fee);
    }

    function _enableTickSpacing(int24 tickSpacing, uint24 fee) internal {
        require(fee > 0 && fee <= 100_000);
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickSpacing > 0 && tickSpacing < 16384);
        require(tickSpacingToFee[tickSpacing] == 0);
        tickSpacingToFee[tickSpacing] = fee;
        _tickSpacings.push(tickSpacing);
        emit TickSpacingEnabled(tickSpacing, fee);
    }

    /// @inheritdoc IRootCLPoolFactory
    function tickSpacings() external view override returns (int24[] memory) {
        return _tickSpacings;
    }

    /// @inheritdoc IRootCLPoolFactory
    function allPoolsLength() external view override returns (uint256) {
        return allPools.length;
    }

    /// @inheritdoc IRootCLPoolFactory
    function isPair(address pool) external view override returns (bool) {
        return _isPool[pool];
    }
}
