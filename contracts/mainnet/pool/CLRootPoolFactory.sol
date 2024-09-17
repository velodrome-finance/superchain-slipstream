// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {ICLRootPoolFactory} from "contracts/mainnet/pool/ICLRootPoolFactory.sol";
import {ICLRootPool} from "contracts/mainnet/pool/ICLRootPool.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";
import "contracts/core/interfaces/ICLFactory.sol";
import "contracts/core/interfaces/fees/IFeeModule.sol";
import "contracts/core/interfaces/IVoter.sol";
import "contracts/core/interfaces/IFactoryRegistry.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@nomad-xyz/src/ExcessivelySafeCall.sol";
import "contracts/core/CLPool.sol";

/// @notice Factory for creating RootPools
contract CLRootPoolFactory is ICLRootPoolFactory {
    /// @inheritdoc ICLRootPoolFactory
    uint256 public immutable override chainId;
    /// @inheritdoc ICLRootPoolFactory
    IVoter public immutable override voter;
    /// @inheritdoc ICLRootPoolFactory
    address public immutable override poolImplementation;
    /// @inheritdoc ICLRootPoolFactory
    IFactoryRegistry public immutable override factoryRegistry;
    /// @inheritdoc ICLRootPoolFactory
    address public override owner;
    /// @inheritdoc ICLRootPoolFactory
    address public override swapFeeManager;
    /// @inheritdoc ICLRootPoolFactory
    address public override swapFeeModule;
    /// @inheritdoc ICLRootPoolFactory
    address public override unstakedFeeManager;
    /// @inheritdoc ICLRootPoolFactory
    address public override unstakedFeeModule;
    /// @inheritdoc ICLRootPoolFactory
    uint24 public override defaultUnstakedFee;
    /// @inheritdoc ICLRootPoolFactory
    mapping(int24 => uint24) public override tickSpacingToFee;
    /// @inheritdoc ICLRootPoolFactory
    mapping(address => mapping(address => mapping(int24 => address))) public override getPool;
    /// @dev Used in VotingEscrow to determine if a contract is a valid pool
    mapping(address => bool) private _isPool;
    /// @inheritdoc ICLRootPoolFactory
    address[] public override allPools;

    int24[] private _tickSpacings;

    constructor(
        address _owner,
        address _swapFeeManager,
        address _unstakedFeeManager,
        address _voter,
        address _poolImplementation,
        uint256 _chainId
    ) {
        owner = _owner;
        swapFeeManager = _swapFeeManager;
        unstakedFeeManager = _unstakedFeeManager;
        voter = IVoter(_voter);
        factoryRegistry = IVoter(_voter).factoryRegistry();
        poolImplementation = _poolImplementation;
        chainId = _chainId;
        defaultUnstakedFee = 100_000;
        // emit OwnerChanged(address(0), _owner);
        // emit SwapFeeManagerChanged(address(0), _swapFeeManager);
        // emit UnstakedFeeManagerChanged(address(0), _unstakedFeeManager);
        // emit DefaultUnstakedFeeChanged(0, 100_000);

        _enableTickSpacing(1, 100);
        _enableTickSpacing(50, 500);
        _enableTickSpacing(100, 500);
        _enableTickSpacing(200, 3_000);
        _enableTickSpacing(2_000, 10_000);
    }

    /// @inheritdoc ICLRootPoolFactory
    function createPool(address tokenA, address tokenB, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        override
        returns (address pool)
    {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(tickSpacingToFee[tickSpacing] != 0);
        require(getPool[token0][token1][tickSpacing] == address(0));
        pool = Clones.cloneDeterministic({
            master: poolImplementation,
            salt: keccak256(abi.encode(token0, token1, tickSpacing))
        });
        CLPool(pool).initialize({
            _factory: address(this),
            _token0: token0,
            _token1: token1,
            _tickSpacing: tickSpacing,
            _factoryRegistry: address(factoryRegistry),
            _sqrtPriceX96: sqrtPriceX96
        });
        allPools.push(pool);
        _isPool[pool] = true;
        getPool[token0][token1][tickSpacing] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][tickSpacing] = pool;
        emit PoolCreated(token0, token1, tickSpacing, pool);
    }

    // /// @inheritdoc ICLFactory
    // function setOwner(address _owner) external override {
    //     address cachedOwner = owner;
    //     require(msg.sender == cachedOwner);
    //     require(_owner != address(0));
    //     emit OwnerChanged(cachedOwner, _owner);
    //     owner = _owner;
    // }
    //
    // /// @inheritdoc ICLFactory
    // function setSwapFeeManager(address _swapFeeManager) external override {
    //     address cachedSwapFeeManager = swapFeeManager;
    //     require(msg.sender == cachedSwapFeeManager);
    //     require(_swapFeeManager != address(0));
    //     swapFeeManager = _swapFeeManager;
    //     emit SwapFeeManagerChanged(cachedSwapFeeManager, _swapFeeManager);
    // }
    //
    // /// @inheritdoc ICLFactory
    // function setUnstakedFeeManager(address _unstakedFeeManager) external override {
    //     address cachedUnstakedFeeManager = unstakedFeeManager;
    //     require(msg.sender == cachedUnstakedFeeManager);
    //     require(_unstakedFeeManager != address(0));
    //     unstakedFeeManager = _unstakedFeeManager;
    //     emit UnstakedFeeManagerChanged(cachedUnstakedFeeManager, _unstakedFeeManager);
    // }
    //
    // /// @inheritdoc ICLFactory
    // function setSwapFeeModule(address _swapFeeModule) external override {
    //     require(msg.sender == swapFeeManager);
    //     require(_swapFeeModule != address(0));
    //     address oldFeeModule = swapFeeModule;
    //     swapFeeModule = _swapFeeModule;
    //     emit SwapFeeModuleChanged(oldFeeModule, _swapFeeModule);
    // }
    //
    // /// @inheritdoc ICLFactory
    // function setUnstakedFeeModule(address _unstakedFeeModule) external override {
    //     require(msg.sender == unstakedFeeManager);
    //     require(_unstakedFeeModule != address(0));
    //     address oldFeeModule = unstakedFeeModule;
    //     unstakedFeeModule = _unstakedFeeModule;
    //     emit UnstakedFeeModuleChanged(oldFeeModule, _unstakedFeeModule);
    // }
    //
    // /// @inheritdoc ICLFactory
    // function setDefaultUnstakedFee(uint24 _defaultUnstakedFee) external override {
    //     require(msg.sender == unstakedFeeManager);
    //     require(_defaultUnstakedFee <= 500_000);
    //     uint24 oldUnstakedFee = defaultUnstakedFee;
    //     defaultUnstakedFee = _defaultUnstakedFee;
    //     emit DefaultUnstakedFeeChanged(oldUnstakedFee, _defaultUnstakedFee);
    // }
    //
    // /// @inheritdoc ICLFactory
    // function getSwapFee(address pool) external view override returns (uint24) {
    //     if (swapFeeModule != address(0)) {
    //         (bool success, bytes memory data) = swapFeeModule.excessivelySafeStaticCall(
    //             200_000, 32, abi.encodeWithSelector(IFeeModule.getFee.selector, pool)
    //         );
    //         if (success) {
    //             uint24 fee = abi.decode(data, (uint24));
    //             if (fee <= 100_000) {
    //                 return fee;
    //             }
    //         }
    //     }
    //     return tickSpacingToFee[CLPool(pool).tickSpacing()];
    // }
    //
    // /// @inheritdoc ICLFactory
    // function getUnstakedFee(address pool) external view override returns (uint24) {
    //     address gauge = voter.gauges(pool);
    //     if (!voter.isAlive(gauge) || gauge == address(0)) {
    //         return 0;
    //     }
    //     if (unstakedFeeModule != address(0)) {
    //         (bool success, bytes memory data) = unstakedFeeModule.excessivelySafeStaticCall(
    //             200_000, 32, abi.encodeWithSelector(IFeeModule.getFee.selector, pool)
    //         );
    //         if (success) {
    //             uint24 fee = abi.decode(data, (uint24));
    //             if (fee <= 1_000_000) {
    //                 return fee;
    //             }
    //         }
    //     }
    //     return defaultUnstakedFee;
    // }

    // /// @inheritdoc ICLFactory
    // function enableTickSpacing(int24 tickSpacing, uint24 fee) public override {
    //     require(msg.sender == owner);
    //     _enableTickSpacing(tickSpacing, fee);
    // }

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

    /// @inheritdoc ICLRootPoolFactory
    function tickSpacings() external view override returns (int24[] memory) {
        return _tickSpacings;
    }

    /// @inheritdoc ICLRootPoolFactory
    function allPoolsLength() external view override returns (uint256) {
        return allPools.length;
    }

    /// @inheritdoc ICLRootPoolFactory
    function isPair(address pool) external view override returns (bool) {
        return _isPool[pool];
    }
}
